# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/systemdboot"

describe Bootloader::SystemdBoot do
  subject do
    sub = described_class.new
    sub
  end

  let(:destdir) { File.expand_path("data/", __dir__) }
  let(:kerneldir) { File.join(destdir, "etc", "kernel") }

  before do
    allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return([])
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    allow(Yast::Package).to receive(:Available).and_return(true)
    FileUtils.mkdir_p(kerneldir)
  end

  after do
    FileUtils.remove_entry(kerneldir) if Dir.exist?(kerneldir)
  end

  describe "#read" do
    it "reads bootloader flags from sysconfig" do
      expect(Bootloader::Systeminfo).to receive(:secure_boot_active?).and_return(true)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)

      subject.read

      expect(subject.secure_boot).to eq true
      expect(subject.cpu_mitigations.to_human_string).to eq "offdd"
      expect(subject.kernel_params.serialize).to eq "splash=silent quiet security=apparmor mitigations=off"
    end
  end

  describe "#write" do
    it "installs bootloader and creates menue entries" do
      allow(subject).to receive(:secure_boot).and_return(false)
      allow(Yast::Stage).to receive(:initial).and_return(true)

      # install bootloader
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      # create menue entries
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")
      # Saving menue timeout
      expect_any_instance_of(CFA::SystemdBoot).to receive(:save)

      subject.menue_timeout = 10
      subject.write
    end
  end

  describe "#packages" do
    it "adds to list shim and mokutil on x86_64 with secure boot" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      subject.secure_boot = true

      expect(subject.packages).to include("shim")
    end
  end

  describe "#summary" do
    it "returns line with boot loader type specified" do
      expect(subject.summary).to include("Boot Loader Type: Systemd Boot")
    end

    it "returns line with secure boot option specified" do
      subject.secure_boot = false

      expect(subject.summary).to include(match(/Secure Boot: disabled/))
    end
  end

  describe "#merge" do
    it "overwrite secure boot and menue timeout if specified in merged one" do
      other = described_class.new
      other.secure_boot = true
      other.menue_timeout = 12

      subject.secure_boot = false
      subject.menue_timeout = 10

      subject.merge(other)

      expect(subject.secure_boot).to eq true
      expect(subject.menue_timeout).to eq 12
    end
  end
end
