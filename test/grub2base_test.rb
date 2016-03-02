require_relative "test_helper"

require "bootloader/grub2base"

describe Bootloader::Grub2Base do
  describe "#read" do
    before do
      allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault", loaded?: false, load: nil, save: nil))
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg", load: nil))
      allow(Bootloader::Sections).to receive(:new).and_return(double("Sections", write: nil))
    end

    it "reads grub default config" do
      grub_default = double(::CFA::Grub2::Default, loaded?: false)
      allow(::CFA::Grub2::Default).to receive(:new).and_return(grub_default)

      expect(grub_default).to receive(:load)

      subject.read
    end

    it "reads sections from grub.cfg file" do
      grub_cfg = double(::CFA::Grub2::GrubCfg, load: nil)
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(grub_cfg)

      expect(Bootloader::Sections).to receive(:new).with(grub_cfg)

      subject.read
    end
  end

  describe "write" do
    before do
      allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault", loaded?: false, load: nil, save: nil))
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg", load: nil))
      allow(Bootloader::Sections).to receive(:new).and_return(double("Sections", write: nil))
    end

    it "stores grub default config" do
      grub_default = double(::CFA::Grub2::Default, loaded?: false)
      expect(::CFA::Grub2::Default).to receive(:new).and_return(grub_default)

      expect(grub_default).to receive(:save)
      # cannot be in before section is created in constructor
      subject.define_singleton_method(:name) { "grub2base" }

      subject.write
    end

    it "stores chosen default section" do
      sections = double("Sections")
      expect(Bootloader::Sections).to receive(:new).and_return(sections)
      subject.define_singleton_method(:name) { "grub2base" }

      expect(sections).to receive(:write)

      subject.write
    end
  end

  describe "#propose" do
    before do
      allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return({})
    end

    describe "os_prober proposal" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).and_return(false)
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      end

      context "on s390" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
        end

        it "disable os probing" do
          subject.propose

          expect(subject.grub_default.os_prober.enabled?).to eq false
        end
      end

      context "on Power PC" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("ppc64")
        end

        it "disable os probing" do
          subject.propose

          expect(subject.grub_default.os_prober.enabled?).to eq false
        end
      end

      context "when Product explicitelly disable os prober" do
        before do
          allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).and_return(true)
        end

        it "disable os probing" do
          subject.propose

          expect(subject.grub_default.os_prober.enabled?).to eq false
        end
      end

      context "otherwise" do
        it "proposes using os probing" do
          subject.propose

          expect(subject.grub_default.os_prober.enabled?).to eq true
        end
      end
    end

    describe "terminal proposal" do
      context "on s390" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
        end

        it "proposes console terminal" do
          subject.propose

          expect(subject.grub_default.terminal).to eq :console
        end
      end

      context "otherwise" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
        end

        it "proposes gfx terminal" do
          subject.propose

          expect(subject.grub_default.terminal).to eq :gfxterm
        end
      end
    end

    it "proposes timeout to 8 seconds" do
      subject.propose

      expect(subject.grub_default.timeout).to eq "8"
    end

    describe "kernel parameters proposal" do
      context "on x86_64" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
        end

        it "proposes kernel parameters used in installation" do
          kernel_params = "verbose suse=rulezz"
          allow(Yast::Kernel).to receive(:GetCmdLine).and_return(kernel_params)

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include(kernel_params)
        end

        it "adds the biggest available swap partition as resume device" do
          allow(Yast::BootStorage).to receive(:available_swap_partitions)
            .and_return(
              "/dev/sda2" => 512,
              "/dev/sdb2" => 1024
            )

          allow(Bootloader::UdevMapping).to receive(:to_mountby_device) { |a| a }

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("resume=/dev/sdb2")
        end

        it "adds additional kernel parameters for given product" do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature)
            .with("globals", "additional_kernel_parameters")
            .and_return("product_aurora=shot")

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("product_aurora=shot")
        end

        it "removes splash argument and always add splash=silent" do
          kernel_params = "splash=verbose,theme:st_theme verbose suse=rulezz"
          allow(Yast::Kernel).to receive(:GetCmdLine).and_return(kernel_params)

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to_not include("splash=verbose,theme:st_theme")
          expect(subject.grub_default.kernel_params.serialize).to include("splash=silent")
        end

        it "adds quiet and showopts arguments" do
          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("quiet showopts")
        end
      end

      context "on s390" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
        end

        context "with TERM=\"linux\"" do
          before do
            ENV["TERM"] = "linux"
          end

          it "proposes to use serial console with \"TERM=linux console=ttyS0 console=ttyS1\"" do
            subject.propose

            expect(subject.grub_default.kernel_params.serialize).to include("TERM=linux console=ttyS0 console=ttyS1")
          end
        end

        context "on other TERM" do
          before do
            ENV["TERM"] = "xterm"
          end

          it "proposes dumb term and sets 8 iuvc terminals" do
            subject.propose

            expect(subject.grub_default.kernel_params.serialize).to include("hvc_iucv=8 TERM=dumb")
          end
        end

        it "adds additional kernel parameters for given product" do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature)
            .with("globals", "additional_kernel_parameters")
            .and_return("product_aurora=shot")

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("product_aurora=shot")
        end

        it "adds the biggest available swap partition as resume device" do
          allow(Yast::BootStorage).to receive(:available_swap_partitions)
            .and_return(
              "/dev/dasda2" => 512,
              "/dev/dasdb2" => 1024
            )

          allow(Bootloader::UdevMapping).to receive(:to_mountby_device) { |a| a }

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("resume=/dev/dasdb2")
        end
      end

      context "on other architectures" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("aarm64")
        end

        it "proposes kernel parameters used in installation" do
          kernel_params = "verbose suse=rulezz"
          allow(Yast::Kernel).to receive(:GetCmdLine).and_return(kernel_params)

          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include(kernel_params)
        end
      end
    end

    it "proposes gfx mode to auto" do
      subject.propose

      expect(subject.grub_default.gfxmode).to eq "auto"
    end

    it "proposes to disable recovery boot entry" do
      subject.propose

      expect(subject.grub_default.recovery_entry.enabled?).to eq false
    end

    it "proposes empty distributor entry" do
      subject.propose

      expect(subject.grub_default.distributor).to eq ""
    end

    it "proposes serial console from its usage on kernel command line" do
      kernel_params = "console=ttyS1,4800n8"
      allow(Yast::Kernel).to receive(:GetCmdLine).and_return(kernel_params)

      subject.propose

      expect(subject.grub_default.serial_console).to eq "serial --unit=1 --speed=4800 --parity=no --word=8"
    end
  end

  describe "#disable_serial_console" do
    it "cleans serial console configuation" do
      subject.grub_default.serial_console = "test console"

      subject.disable_serial_console

      expect(subject.grub_default.serial_console).to be_empty
    end

    it "removes serial console parameters from kernel command line configuration" do
      subject.grub_default.kernel_params.replace("verbose console=ttyS1,4800n1")

      subject.disable_serial_console

      expect(subject.grub_default.kernel_params.serialize).to eq "verbose"
    end
  end

  describe "#enable_serial_console" do
    before do
      # fix architecture as serial console device is different on different architectures
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    end

    it "sets serial console configuration according to argument" do
      subject.grub_default.serial_console = ""

      subject.enable_serial_console("serial --unit=1 --speed=4800 --parity=no --word=8")

      expect(subject.grub_default.serial_console).to eq "serial --unit=1 --speed=4800 --parity=no --word=8"
    end

    it "sets serial console parameter to kernel command line configuration according to parameter" do
      subject.grub_default.kernel_params.replace("")

      subject.enable_serial_console("serial --unit=1 --speed=4800 --parity=no --word=8")

      expect(subject.grub_default.kernel_params.serialize).to eq "console=ttyS1,4800n8"
    end
  end
end
