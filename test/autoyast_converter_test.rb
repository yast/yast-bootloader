# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/autoyast_converter"
require "bootloader/grub2"

Yast.import "Arch"

describe Bootloader::AutoyastConverter do
  subject { described_class }

  describe ".import" do
    before do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      allow(Bootloader::BootloaderFactory).to receive(:proposed).and_return(Bootloader::Grub2.new)
      allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).with("globals", "enable_systemd_boot").and_return(true)
    end

    it "create bootloader of passed loader_type" do
      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(
        "loader_type" => "grub2-efi"
      )

      expect(subject.import(section)).to be_a(Bootloader::Grub2EFI)
    end

    it "use proposed bootloader type if loader type missing" do
      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes({})

      expect(subject.import(section)).to be_a(Bootloader::Grub2)
    end

    it "use proposed bootloader type if loader type is \"default\"" do
      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(
        "loader_type" => "default"
      )

      expect(subject.import(section)).to be_a(Bootloader::Grub2)
    end

    it "raises exception if loader type is not supported" do
      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(
        "loader_type" => "lilo"
      )

      expect { subject.import(section) }.to raise_error(Bootloader::UnsupportedBootloader)
    end

    it "import configuration to returned bootloader" do
      data = {
        "append"            => "verbose nomodeset resume=/dev/disk/by-uuid/bla-bla",
        # /dev/sda exists on mocked trivial system, so it should not be removed
        "xen_kernel_append" => "verbose nomodeset resume=/dev/sda1",
        "terminal"          => "gfxterm",
        "os_prober"         => "true",
        "hiddenmenu"        => "true",
        "timeout"           => 10,
        "activate"          => "true",
        "generic_mbr"       => "false",
        "trusted_grub"      => "true",
        "update_nvram"      => "true",
        "boot_boot"         => "true",
        "password"          => {
          "value"        => "test",
          "encrypted"    => "true", # if changed to false, then also mock grub2-mkpasswd
          "unrestricted" => "true"
        }
      }

      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(
        "global" => data
      )
      bootloader = subject.import(section)

      expect(bootloader.grub_default.kernel_params.serialize).to eq "verbose nomodeset"
      expect(
        bootloader.grub_default.xen_hypervisor_params.serialize
      ).to eq "verbose nomodeset resume=/dev/sda1"
      expect(bootloader.grub_default.terminal).to eq [:gfxterm]
      expect(bootloader.grub_default.os_prober).to be_enabled
      expect(bootloader.grub_default.hidden_timeout).to eq "10"
      expect(bootloader.stage1).to be_activate
      expect(bootloader.stage1.boot_partition?).to eq true
      expect(bootloader.trusted_boot).to eq true
      expect(bootloader.update_nvram).to eq true
      expect(bootloader.password.used?).to eq true
      expect(bootloader.password.unrestricted?).to eq true
    end

    it "imports device map for grub2 on intel architecture" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      data = {
        "loader_type" => "grub2",
        "device_map"  => [
          { "firmware" => "hd0", "linux" => "/dev/vda" },
          { "firmware" => "hd1", "linux" => "/dev/vdb" }
        ]
      }

      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(data)
      bootloader = subject.import(section)
      expect(bootloader.device_map.system_device_for("hd0")).to eq "/dev/vda"
      expect(bootloader.device_map.system_device_for("hd1")).to eq "/dev/vdb"
    end

    it "supports SLE9 format" do
      data = {
        "activate"      => "true",
        "loader_device" => "/dev/sda1"
      }

      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(data)
      bootloader = subject.import(section)

      expect(bootloader.stage1).to be_activate
      expect(bootloader.stage1).to include("/dev/sda1")
    end

    it "supports systemd-boot bootloader" do
      data = {
        "loader_type" => "systemd-boot",
        "global"      => { "secure_boot" => true,
                           "timeout"     => 30 }
      }

      section = Bootloader::AutoinstProfile::BootloaderSection.new_from_hashes(data)
      bootloader = subject.import(section)
      expect(bootloader).to be_a(Bootloader::SystemdBoot)
      expect(bootloader.menu_timeout).to eq 30
      expect(bootloader.secure_boot).to eq true
    end
  end

  describe ".export" do
    let(:bootloader) { Bootloader::Grub2.new }

    before do
      devicegraph_stub("storage_lvm.yaml")
    end

    it "export loader type" do
      expect(subject.export(bootloader)["loader_type"]).to eq "grub2"
    end

    it "export to global key configuration" do
      bootloader.grub_default.kernel_params.replace("verbose nomodeset resume=/dev/sda")
      bootloader.grub_default.terminal = [:gfxterm]
      bootloader.grub_default.os_prober.enable
      bootloader.grub_default.hidden_timeout = "10"
      bootloader.stage1.activate = true
      bootloader.trusted_boot = true
      bootloader.password.unrestricted = false
      bootloader.password.used = true
      bootloader.password.encrypted_password = "blabla"

      expected_export = {
        "append"          => "verbose nomodeset",
        "terminal"        => "gfxterm",
        "os_prober"       => "true",
        "hiddenmenu"      => "true",
        "timeout"         => 10,
        "trusted_grub"    => "true",
        "update_nvram"    => "true",
        "cpu_mitigations" => "manual",
        "password"        => {
          "unrestricted" => "false",
          "value"        => "blabla",
          "encrypted"    => "true"
        }
      }

      expect(subject.export(bootloader)["global"]).to eq expected_export
    end

    context "for grub2-efi bootloader" do
      let(:bootloader) { Bootloader::Grub2EFI.new }

      it "exports secure boot key" do
        bootloader.secure_boot = true
        expect(subject.export(bootloader)["global"]["secure_boot"]).to eq "true"
      end
      it "exports update nvram key" do
        bootloader.update_nvram = false
        expect(subject.export(bootloader)["global"]["update_nvram"]).to eq "false"
      end
    end

    context "for systemd-boot bootloader" do
      let(:bootloader) { Bootloader::SystemdBoot.new }

      it "exports secure boot key" do
        bootloader.secure_boot = true
        expect(subject.export(bootloader)["global"]["secure_boot"]).to eq true
      end
      it "exports timeout key" do
        bootloader.menu_timeout = 20
        expect(subject.export(bootloader)["global"]["timeout"]).to eq 20
      end
    end
  end
end
