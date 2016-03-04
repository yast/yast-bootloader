#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/grub_install"

describe Bootloader::GrubInstall do
  describe "#execute" do
    def stub_arch(arch)
      allow(Yast::Arch).to receive(:architecture).and_return(arch)
    end

    def expect_grub2_install(target, device: nil)
      params = [/grub2-install/, "--target=#{target}", "--force", "--skip-fs-probe"]
      params << device if device

      expect(Yast::Execute).to receive(:locally)
        .with(params)
    end

    context "initialized with efi: true" do
      subject { Bootloader::GrubInstall.new(efi: true) }

      it "runs shim-install instead of grub2-install if secure_boot: true passed" do
        expect(Yast::Execute).to receive(:locally)
          .with([/shim-install/, "--config-file=/boot/grub2/grub.cfg"])

        subject.execute(secure_boot: true)
      end

      it "runs with target i386-efi on i386" do
        stub_arch("i386")
        expect_grub2_install("i386-efi")

        subject.execute
      end

      it "runs with target x86_64-efi on x86_64" do
        stub_arch("x86_64")
        expect_grub2_install("x86_64-efi")

        subject.execute
      end

      it "raise exception on ppc64" do
        stub_arch("ppc64")

        expect { subject.execute }.to raise_error(RuntimeError)
      end

      it "raise exception on s390" do
        stub_arch("s390_64")

        expect { subject.execute }.to raise_error(RuntimeError)
      end

      it "runs with target arm64-efi on aarch64" do
        stub_arch("aarch64")
        expect_grub2_install("arm64-efi")

        subject.execute
      end

      it "raise exception for other architectures" do
        stub_arch("punks_not_dead")

        expect { subject.execute }.to raise_error(RuntimeError)
      end
    end

    context "initialized with efi:false" do
      subject { Bootloader::GrubInstall.new(efi: false) }

      it "raise exception if secure_boot: true passed" do
        expect { subject.execute(secure_boot: true) }.to raise_error(RuntimeError)
      end

      it "runs for each device passed in devices" do
        stub_arch("x86_64")
        expect_grub2_install("i386-pc", device: "/dev/sda")
        expect_grub2_install("i386-pc", device: "/dev/sdb")
        expect_grub2_install("i386-pc", device: "/dev/sdc")

        subject.execute(devices: ["/dev/sda", "/dev/sdb", "/dev/sdc"])
      end

      it "runs with target i386-pc on i386" do
        stub_arch("i386")
        expect_grub2_install("i386-pc", device: "/dev/sda")

        subject.execute(devices: ["/dev/sda"])
      end

      it "runs with target i386-pc on x86_64" do
        stub_arch("x86_64")
        expect_grub2_install("i386-pc", device: "/dev/sda")

        subject.execute(devices: ["/dev/sda"])
      end

      it "runs with target powerpc-ieee1275 on ppc64" do
        stub_arch("ppc64")
        expect_grub2_install("powerpc-ieee1275", device: "/dev/sda")

        subject.execute(devices: ["/dev/sda"])
      end

      it "runs with target s390x-emu on s390" do
        stub_arch("s390_64")

        expect_grub2_install("s390x-emu", device: "/dev/dasda1")

        subject.execute(devices: ["/dev/dasda1"])
      end

      it "raise exception on aarch64" do
        stub_arch("aarch64")

        expect { subject.execute }.to raise_error(RuntimeError)
      end

      it "raise exception for other architectures" do
        stub_arch("punks_not_dead")

        expect { subject.execute }.to raise_error(RuntimeError)
      end

    end
  end
end
