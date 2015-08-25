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

  describe ".Import" do
    before do
      # ensure flags are reset
      Yast::BootCommon.was_read = false
      Yast::BootCommon.was_proposed = false
      Yast::BootCommon.changed = false
      Yast::BootCommon.location_changed = false
    end

    # FIXME: looks useless as import is used in autoinstallation and in such case reset do nothing
    it "resets configuration" do
      expect(subject).to receive(:Reset)

      subject.Import({})
    end

    it "marks that configuration is read" do
      subject.Import({})

      expect(Yast::BootCommon.was_read).to eq true
    end

    it "marks that configuration is already proposed" do
      subject.Import({})

      expect(Yast::BootCommon.was_proposed).to eq true
    end

    it "marks that configuration is changed" do
      subject.Import({})

      expect(Yast::BootCommon.changed).to eq true
    end

    it "marks that stage1 location changed" do
      subject.Import({})

      expect(Yast::BootCommon.location_changed).to eq true
    end

    it "sets bootloader from key \"loader_type\"" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with("grub2")
      subject.Import("loader_type" => "grub2")
    end

    it "sets proposed bootloader if not set in data" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with(Yast::BootCommon.getLoaderType(true))
      subject.Import({})
    end

    it "acts like missing if \"loader_type\" value is empty" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with(Yast::BootCommon.getLoaderType(true))
      subject.Import("loader_type" => "")
    end

    it "pass initrd specific map to initrd module" do
      initrd_map = {
        "list"     => ["nouveau", "nvidia"],
        "settings" => {
          "nouveau" => {
            "debug" => "1"
          }
        }
      }
      expect(Yast::Initrd).to receive(:Import).with(initrd_map)

      subject.Import("initrd" => initrd_map)
    end

    it "sets passed \"write_settings\" map" do
      write_settings = { "key" => "value" }

      subject.Import("write_settings" => write_settings)
      expect(Yast::BootCommon.write_settings).to eq write_settings
    end
  end

  describe ".ReadOrProposeIfNeeded" do
    before do
      allow(subject).to receive(:Propose)
      allow(subject).to receive(:Read)
      Yast::BootCommon.was_read = false
      Yast::BootCommon.was_proposed = false
    end

    it "does nothing if already read" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      Yast::BootCommon.was_read = true

      subject.ReadOrProposeIfNeeded
    end

    it "does nothing if already proposed" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      Yast::BootCommon.was_proposed = true

      subject.ReadOrProposeIfNeeded
    end

    it "does nothing in config mode" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      expect(Yast::Mode).to receive(:config).and_return(true)

      subject.ReadOrProposeIfNeeded
    end

    it "propose configuration in initial stage except update mode" do
      expect(subject).to receive(:Propose)
      expect(subject).to_not receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(true)
      expect(Yast::Mode).to receive(:update).and_return(false)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in normal stage" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::Mode).to receive(:update).and_return(false)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in update mode" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Mode).to receive(:update).and_return(true)
      allow(subject).to receive(:UpdateConfiguration)

      subject.ReadOrProposeIfNeeded
    end

    it "calls .UpdateConfiguration in update mode" do
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Mode).to receive(:update).and_return(true)
      expect(subject).to receive(:UpdateConfiguration)

      subject.ReadOrProposeIfNeeded
    end
  end

  describe ".modify_kernel_params" do
    let(:initial_lines) { {} }
    let(:params) { { "crashkernel" => "256M" } }
    let(:append) { "crashkernel=256M" }

    before do
      Yast::BootCommon.changed = false
    end

    around do |example|
      old_globals_value = Yast::BootCommon.globals
      Yast::BootCommon.globals = initial_lines
      example.run
      Yast::BootCommon.globals = old_globals_value
    end

    context "when no parameters are passed" do
      it "raises an ArgumentError exception" do
        expect { subject.modify_kernel_params(:common) }.to raise_error(ArgumentError)
        expect(Yast::BootCommon.changed).to eq(false)
      end
    end

    context "when target does not exist" do
      it "raises an ArgumentError exception" do
        expect { subject.modify_kernel_params(:unknown, params) }.to raise_error(ArgumentError)
        expect(Yast::BootCommon.changed).to eq(false)
      end
    end

    context "when no target is specified" do
      it "uses :common by default" do
        subject.modify_kernel_params(params)

        expect(Yast::BootCommon.globals[kernel_line(:common)]).to eq(append)
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when a target is specified" do
      it "adds parameter for that target" do
        subject.modify_kernel_params(:xen_guest, params)

        expect(Yast::BootCommon.globals[kernel_line(:xen_guest)]).to eq(append)
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when multiple targets are specified" do
      it "adds parameters to each target" do
        subject.modify_kernel_params(:xen_host, :xen_guest, params)

        expect(Yast::BootCommon.globals[kernel_line(:xen_host)]).to eq(append)
        expect(Yast::BootCommon.globals[kernel_line(:xen_guest)]).to eq(append)
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when targets are specified as an array" do
      it "adds parameters to each target" do
        subject.modify_kernel_params([:xen_host, :xen_guest], params)

        expect(Yast::BootCommon.globals[kernel_line(:xen_host)]).to eq(append)
        expect(Yast::BootCommon.globals[kernel_line(:xen_guest)]).to eq(append)
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when a parameter is set to be removed" do
      let(:initial_lines) { { kernel_line(:common) => "quiet #{append}" } }
      let(:params) { { "quiet" => :missing } }

      it "removes parameter from the given target" do
        subject.modify_kernel_params(:common, params)

        expect(Yast::BootCommon.globals[kernel_line(:common)]).to eq(append)
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when a parameter is set to be just present" do
      let(:params) { { "quiet" => :present } }

      it "adds the parameter to the given target without any value" do
        subject.modify_kernel_params(:common, params)

        expect(Yast::BootCommon.globals[kernel_line(:common)]).to eq("quiet")
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end

    context "when parameter is 'vga'" do
      let(:params) { { "vga" => "80" } }

      it "adds the parameter as 'vgamode' to the global scope and does not mark BootCommon as 'modified'" do
        subject.modify_kernel_params(:common, params)
        expect(Yast::BootCommon.globals["vgamode"]).to eq("80")
        expect(Yast::BootCommon.globals).to_not have_key("__modified")
        expect(Yast::BootCommon.changed).to eq(false)
      end
    end

    context "when parameter is 'root' (cannot be modified)" do
      let(:params) { { "root" => "/dev/sda1" } }

      it "makes no changes" do
        expect { subject.modify_kernel_params(:common, params) }
          .to_not change { Yast::BootCommon.globals }
        expect(Yast::BootCommon.changed).to eq(false)
      end
    end

    context "when multiple values are specified for a parameter" do
      let(:params) { { "crashkernel" => ["256M,low", "1024M,high"] } }

      it "adds the parameter multiple times" do
        subject.modify_kernel_params(:common, params)

        expect(Yast::BootCommon.globals[kernel_line(:common)])
          .to eq("crashkernel=256M,low crashkernel=1024M,high")
        expect(Yast::BootCommon.globals["__modified"]).to eq("1")
        expect(Yast::BootCommon.changed).to eq(true)
      end
    end
  end

  describe ".kernel_param" do
    let(:initial_lines) do
      { kernel_line(:common) => "quiet verbose=1 crashkernel=256M,low crashkernel=1024M,high" }
    end

    around do |example|
      old_value = Yast::BootCommon.globals
      Yast::BootCommon.globals = initial_lines
      example.run
      Yast::BootCommon.globals = old_value
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
