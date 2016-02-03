require_relative "test_helper"

Yast.import "Bootloader"

describe Yast::Bootloader do
  # Helper method to grab the kernel line for a given target.
  #
  # @param  [Symbol] target Name of the kernel (:common, :xen_host, etc.)
  # @return [String] Name of the kernel line to modify (:append, :xen_host_append, etc.)
  def kernel_line(target)
    Yast::BootloaderClass::FLAVOR_KERNEL_LINE_MAP[target]
  end

  subject { Yast::Bootloader }

  let(:bootloader) { ::Bootloader::BootloaderFactory.current }

  before do
    # clean cache
    ::Bootloader::BootloaderFactory.instance_variable_set(:@cached_bootloaders, {})
    ::Bootloader::BootloaderFactory.current_name = "grub2"
  end

  describe ".Import" do
    before do
    end

    it "resets configuration"

    it "marks that configuration is read"

    it "marks that configuration is already proposed"

    it "marks that configuration is changed"

    it "marks that stage1 location changed"

    it "sets bootloader from key \"loader_type\""

    it "sets proposed bootloader if not set in data"

    it "acts like missing if \"loader_type\" value is empty"

    it "pass initrd specific map to initrd module"
    #      initrd_map = {
    #        "list"     => ["nouveau", "nvidia"],
    #        "settings" => {
    #          "nouveau" => {
    #            "debug" => "1"
    #          }
    #        }
    #      }
    #      expect(Yast::Initrd).to receive(:Import).with(initrd_map)
    #
    #      subject.Import("initrd" => initrd_map)
    #    end

    it "sets passed \"write_settings\" map"
  end

  describe ".ReadOrProposeIfNeeded" do
    before do
      allow(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::Mode).to receive(:update).and_return(false)
      allow(Yast::Mode).to receive(:config).and_return(false)

    end

    it "does nothing if already read" do
      bootloader.instance_variable_set(:@read, true)
      expect(subject).to_not receive(:Read)
      expect(subject).to_not receive(:Propose)

      subject.ReadOrProposeIfNeeded
    end

    it "does nothing if already proposed" do
      bootloader.instance_variable_set(:@proposed, true)
      expect(subject).to_not receive(:Read)
      expect(subject).to_not receive(:Propose)

      subject.ReadOrProposeIfNeeded
    end

    it "propose in config mode" do
      expect(subject).to receive(:Propose)
      expect(subject).to_not receive(:Read)
      expect(Yast::Mode).to receive(:config).and_return(true)

      subject.ReadOrProposeIfNeeded
    end

    it "propose configuration in initial stage except update mode" do
      expect(subject).to receive(:Propose)
      expect(subject).to_not receive(:Read)
      allow(Yast::Mode).to receive(:config).and_return(false)
      allow(Yast::Mode).to receive(:update).and_return(false)
      allow(Yast::Stage).to receive(:initial).and_return(true)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in normal stage" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in update mode" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)
      allow(Yast::Mode).to receive(:update).and_return(true)
      allow(Yast::Stage).to receive(:initial).and_return(true)

      subject.ReadOrProposeIfNeeded
    end
  end

  describe ".modify_kernel_params" do
    let(:initial_lines) { {} }
    let(:params) { { "crashkernel" => "256M" } }
    let(:append) { "crashkernel=256M" }

    context "when no parameters are passed" do
      it "raises an ArgumentError exception" do
        expect { subject.modify_kernel_params(:common) }.to raise_error(ArgumentError)
      end
    end

    context "when target does not exist" do
      it "raises an ArgumentError exception" do
        expect { subject.modify_kernel_params(:unknown, params) }.to raise_error(ArgumentError)
      end
    end

    context "when no target is specified" do
      it "uses :common by default" do
        subject.modify_kernel_params(params)

        expect(bootloader.grub_default.kernel_params.serialize).to eq append
      end
    end

    context "when a target is specified" do
      it "adds parameter for that target" do
        subject.modify_kernel_params(:xen_guest, params)

        expect(bootloader.grub_default.xen_kernel_params.serialize).to eq append
      end
    end

    context "when multiple targets are specified" do
      it "adds parameters to each target" do
        subject.modify_kernel_params(:xen_host, :xen_guest, params)

        expect(bootloader.grub_default.xen_kernel_params.serialize).to eq append
        expect(bootloader.grub_default.xen_hypervisor_params.serialize).to eq append
      end
    end

    context "when targets are specified as an array" do
      it "adds parameters to each target" do
        subject.modify_kernel_params([:xen_host, :xen_guest], params)

        expect(bootloader.grub_default.xen_kernel_params.serialize).to eq append
        expect(bootloader.grub_default.xen_hypervisor_params.serialize).to eq append
      end
    end

    context "when a parameter is set to be removed" do
      before do
        bootloader.grub_default.kernel_params.add_parameter("quiet", true)
        bootloader.grub_default.kernel_params.add_parameter("silent", true)
      end
      let(:params) { { "quiet" => :missing } }

      it "removes parameter from the given target" do
        subject.modify_kernel_params(:common, params)

        expect(bootloader.grub_default.kernel_params.serialize).to eq "silent"
      end
    end

    context "when a parameter is set to be just present" do
      let(:params) { { "quiet" => :present } }

      it "adds the parameter to the given target without any value" do
        subject.modify_kernel_params(:common, params)

        expect(bootloader.grub_default.kernel_params.serialize).to eq "quiet"
      end
    end

    context "when multiple values are specified for a parameter" do
      let(:params) { { "crashkernel" => ["256M,low", "1024M,high"] } }

      it "adds the parameter multiple times" do
        subject.modify_kernel_params(:common, params)

        expect(bootloader.grub_default.kernel_params.serialize).to eq "crashkernel=256M,low crashkernel=1024M,high"
      end
    end
  end

  describe ".kernel_param" do
    before do
      bootloader.grub_default.kernel_params.replace("quiet verbose=1 crashkernel=256M,low crashkernel=1024M,high")
    end

    context "when parameter does not exist" do
      it "returns 'false'" do
        expect(subject.kernel_param(:common, "nothing")).to eq(:missing)
      end
    end

    context "when parameter exists but has no value" do
      it "returns 'true'" do
        expect(subject.kernel_param(:common, "quiet")).to eq(:present)
      end
    end

    context "when parameter exists and has one value" do
      it "returns the value" do
        expect(subject.kernel_param(:common, "verbose")).to eq("1")
      end
    end

    context "when parameter exists but has multiple values" do
      it "returns all the values" do
        expect(subject.kernel_param(:common, "crashkernel"))
          .to eq(["256M,low", "1024M,high"])
      end
    end
  end
end
