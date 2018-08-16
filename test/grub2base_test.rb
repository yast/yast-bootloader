require_relative "test_helper"

require "bootloader/grub2base"

describe Bootloader::Grub2Base do
  describe "#read" do
    before do
      allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault", loaded?: false, load: nil, save: nil))
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg", load: nil))
      allow(Bootloader::Sections).to receive(:new).and_return(double("Sections").as_null_object)
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

    it "reads trusted boot configuration from sysconfig" do
      mocked_sysconfig = ::Bootloader::Sysconfig.new(trusted_boot: true)
      expect(::Bootloader::Sysconfig).to receive(:from_system).and_return(mocked_sysconfig)

      subject.read

      expect(subject.trusted_boot).to eq true

      mocked_sysconfig = ::Bootloader::Sysconfig.new(trusted_boot: false)
      expect(::Bootloader::Sysconfig).to receive(:from_system).and_return(mocked_sysconfig)

      subject.read

      expect(subject.trusted_boot).to eq false
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

        context "with TERM=\"linux\"" do
          before do
            allow(ENV).to receive(:"[]").with("TERM").and_return("linux")
          end

          it "proposes to use serial terminal" do
            subject.propose

            expect(subject.grub_default.terminal).to eq :serial
          end
        end

        context "on other TERM" do
          before do
            allow(ENV).to receive(:"[]").with("TERM").and_return("xterm")
          end

          it "proposes to use console terminal" do
            subject.propose

            expect(subject.grub_default.terminal).to eq :console
          end
        end
      end

      context "on ppc" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("ppc64")
        end

        it "proposes to use console terminal" do
          subject.propose

          expect(subject.grub_default.terminal).to eq :console
        end

        it "sets GFXPAYLOAD_LINUX to text" do
          subject.propose

          expect(subject.grub_default.generic_get("GRUB_GFXPAYLOAD_LINUX")).to eq "text"
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

    it "proposes using btrfs snapshots always to true" do
      subject.propose

      expect(subject.grub_default.generic_get("SUSE_BTRFS_SNAPSHOT_BOOTING")).to eq "true"
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

        it "adds \"quiet\" argument" do
          subject.propose

          expect(subject.grub_default.kernel_params.serialize).to include("quiet")
        end
      end

      context "on s390" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
        end

        context "with TERM=\"linux\"" do
          before do
            allow(ENV).to receive(:"[]").with("TERM").and_return("linux")
          end

          it "proposes to use serial console with \"TERM=linux console=ttyS0 console=ttyS1\"" do
            subject.propose

            expect(subject.grub_default.kernel_params.serialize).to include("TERM=linux console=ttyS0 console=ttyS1")
          end
        end

        context "on other TERM" do
          before do
            allow(ENV).to receive(:"[]").with("TERM").and_return("xterm")
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

    context "xen hyperviser kernel parameters proposal" do
      it "do nothing if there is no framebuffer" do
        allow(Dir).to receive(:[]).and_return([])

        subject.propose

        expect(subject.grub_default.xen_hypervisor_params.parameter("vga")).to eq false
      end

      it "propose vga parameter if there is framebuffer" do
        allow(Dir).to receive(:[]).and_return(["/dev/fb0"])

        subject.propose

        expect(subject.grub_default.xen_hypervisor_params.parameter("vga")).to eq "gfx-1024x768x16"
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

    it "proposes serial console from its usage on kernel command line on non-s390" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      kernel_params = "console=ttyS1,4800n8"
      allow(Yast::Kernel).to receive(:GetCmdLine).and_return(kernel_params)

      subject.propose

      expect(subject.grub_default.serial_console).to eq "serial --unit=1 --speed=4800 --parity=no --word=8"
    end

    it "proposes to disable trusted boot" do
      subject.propose

      expect(subject.trusted_boot).to eq false
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

  describe "#merge" do
    let(:other) do
      other = Bootloader::Grub2Base.new
      other.define_singleton_method(:name) { "grub2base" }
      other
    end

    before do
      allow(Yast::Execute).to receive(:on_target).and_return("")
      subject.define_singleton_method(:name) { "grub2base" }
    end

    it "for default configuration prefer value from other if defined" do
      subject.grub_default.default = "0"
      other.grub_default.default = "saved"

      subject.grub_default.terminal = :gfxterm

      subject.grub_default.os_prober.enable
      other.grub_default.os_prober.disable

      subject.merge(other)

      expect(subject.grub_default.default).to eq "saved"
      expect(subject.grub_default.terminal).to eq :gfxterm
      expect(subject.grub_default.os_prober).to be_disabled
    end

    it "for kernel line place subject params and then merged ones" do
      subject.grub_default.kernel_params.replace("verbose debug=true")
      other.grub_default.kernel_params.replace("silent debug=false 3")

      subject.merge(other)

      expect(subject.grub_default.kernel_params.serialize).to eq "verbose debug=true silent debug=false 3"
    end

    it "use grub2 password configuration specified in merged object" do
      allow(other.password).to receive(:password?).and_return(true)

      subject.merge(other)

      expect(subject.password).to be_password
    end

    it "use terminal configuration specified in the merged object" do
      TERMINAL_DEFINITION = [:console, :serial].freeze

      allow(other.grub_default).to receive(:terminal).and_return(TERMINAL_DEFINITION)

      subject.merge(other)

      expect(subject.grub_default.terminal).to eql TERMINAL_DEFINITION
    end

    it "overwrites default section with merged one if specified" do
      allow(other.sections).to receive(:all).and_return(["Win crap", "openSUSE"])
      allow(subject.sections).to receive(:all).and_return(["Win crap", "openSUSE"])

      other.sections.default = "openSUSE"

      subject.merge(other)

      expect(subject.sections.default).to eq "openSUSE"

      other.sections.default = ""

      subject.merge(other)

      expect(subject.sections.default).to eq "openSUSE"
    end

    it "overwrites pmbr action if merged one define it" do
      subject.pmbr_action = :add
      other.pmbr_action = :nothing

      subject.merge(other)

      expect(subject.pmbr_action).to eq :nothing
    end

    it "overwrites trusted boot configuration if merged define it" do
      subject.trusted_boot = true
      other.trusted_boot = false

      subject.merge(other)

      expect(subject.trusted_boot).to eq false
    end
  end
end
