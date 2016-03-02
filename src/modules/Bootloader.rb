# encoding: utf-8

# File:
#      modules/Bootloader.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Bootloader installation and configuration base module
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
require "yast"
require "bootloader/sysconfig"
require "bootloader/bootloader_factory"
require "cfa/matcher"

module Yast
  class BootloaderClass < Module
    include Yast::Logger

    BOOLEAN_MAPPING = { true => :present, false => :missing }

    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "Installation"
      Yast.import "Initrd"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Progress"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Directory"

      # fate 303395
      Yast.import "ProductFeatures"
      # Write is repeating again
      # Because of progress bar during inst_finish
      @repeating_write = false

      # installation proposal help variables

      # Configuration was changed during inst. proposal if true
      @proposed_cfg_changed = false

      # old vga value handling function

      # old value of vga parameter of default bootloader section
      @old_vga = nil

      # general functions

      @test_abort = nil
    end

    # Check whether abort was pressed
    # @return [Boolean] true if abort was pressed
    def testAbort
      return false if Mode.commandline

      UI.PollInput == :abort
    end

    # bnc #419197 yast2-bootloader does not correctly initialise libstorage
    # Function try initialize yast2-storage
    # if other module used it then don't continue with initialize
    # @return [Boolean] true on success

    def checkUsedStorage
      Storage.InitLibstorage(true) || !Mode.normal
    end

    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      ReadOrProposeIfNeeded()
      # TODO: implement it using new way
      #      out = {
      #        "loader_type"     => getLoaderType,
      #        "initrd"          => Initrd.Export,
      #        "specific"        => blExport,
      #        "write_settings"  => BootCommon.write_settings,
      #        "loader_device"   => BootCommon.loader_device,
      #        "loader_location" => BootCommon.selected_location
      #      }
      #      log.info "Exporting settings: #{out}"
      #      out
      {}
    end

    # Import settings from a map
    # @param [Hash] settings map of bootloader settings
    # @return [Boolean] true on success
    def Import(settings)
      settings = deep_copy(settings)
      log.info "Importing settings: #{settings}"
      # TODO: implement it using new way
      #      Reset()
      #
      #      BootCommon.was_read = true
      #      BootCommon.was_proposed = true
      #      BootCommon.changed = true
      #      BootCommon.location_changed = true
      #
      #      settings["loader_type"] = nil if settings["loader_type"] == ""
      #      # if bootloader is not set, then propose it
      #      loader_type = settings["loader_type"] || BootCommon.getLoaderType(true)
      #      # Explitelly set it to ensure it is installed
      #      BootCommon.setLoaderType(loader_type)
      #
      #      # import loader_device and selected_location only for bootloaders
      #      # that have not phased them out yet
      #      BootCommon.loader_device = settings["loader_device"] || ""
      #      BootCommon.selected_location = settings["loader_location"] || "custom"
      #
      #      # FIXME: obsolete for grub (but inactive through the outer "if" now anyway):
      #      # for grub, always correct the bootloader device according to
      #      # selected_location (or fall back to value of loader_device)
      #      if Arch.i386 || Arch.x86_64
      #        BootCommon.loader_device = BootCommon.GetBootloaderDevice
      #      end
      #
      #      Initrd.Import(settings["initrd"] || {})
      #      ret = blImport(settings["specific"] || {})
      #      BootCommon.write_settings = settings["write_settings"] || {}
      #      ret
    end

    # Read settings from disk
    # @return [Boolean] true on success
    def Read
      log.info "Reading configuration"
      # run Progress bar
      stages = [
        # progress stage, text in dialog (short, infinitiv)
        _("Check boot loader"),
        # progress stage, text in dialog (short, infinitiv)
        _("Read partitioning"),
        # progress stage, text in dialog (short, infinitiv)
        _("Load boot loader settings")
      ]
      titles = [
        # progress step, text in dialog (short)
        _("Checking boot loader..."),
        # progress step, text in dialog (short)
        _("Reading partitioning..."),
        # progress step, text in dialog (short)
        _("Loading boot loader settings...")
      ]
      # dialog header
      Progress.New(
        _("Initializing Boot Loader Configuration"),
        " ",
        3,
        stages,
        titles,
        ""
      )

      Progress.NextStage
      return false if testAbort

      Progress.NextStage
      return false if !checkUsedStorage

      # While calling "yast clone_system" and while cloning bootloader
      # in the AutoYaST module, libStorage has to be set to "normal"
      # mode in order to read mountpoints correctly.
      # (bnc#950105)
      old_mode = Mode.mode
      if Mode.config
        Mode.SetMode("normal")
        StorageDevices.InitDone # Set StorageDevices flag disks_valid to true
      end

      BootStorage.detect_disks
      Mode.SetMode(old_mode) if old_mode == "autoinst_config"

      Progress.NextStage
      return false if testAbort

      ::Bootloader::BootloaderFactory.current.read

      Progress.Finish

      true
    end

    # Reset bootloader settings
    def Reset
      return if Mode.autoinst
      log.info "Reseting configuration"
      # TODO: consider what to actually do in reset

      nil
    end

    # Propose bootloader settings
    def Propose
      log.info "Proposing configuration"
      # always have a current target map available in the log
      log.info "unfiltered target map: #{Storage.GetTargetMap.inspect}"
      ::Bootloader::BootloaderFactory.current.propose

      log.info "Proposed settings: #{Export()}"

      nil
    end

    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      # kokso: additional warning that root partition is nfs type -> bootloader will not be installed
      if BootStorage.disks_with_boot_partition == "/dev/nfs"
        log.info "Bootloader::Summary() -> Boot partition is nfs type, bootloader will not be installed."
        return _("The boot partition is of type NFS. Bootloader cannot be installed.")
      end

      ::Bootloader::BootloaderFactory.current.summary
    end

    # Update the whole configuration
    # @return [Boolean] true on success
    def Update
      Write() # write also reads the configuration and updates it
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ReadOrProposeIfNeeded()

      mark_as_changed

      log.info "Writing bootloader configuration"

      # run Progress bar
      stages = [
        # progress stage, text in dialog (short)
        _("Create initrd"),
        # progress stage, text in dialog (short)
        _("Save boot loader configuration")
      ]
      titles = [
        # progress step, text in dialog (short)
        _("Creating initrd..."),
        # progress step, text in dialog (short)
        _("Saving boot loader configuration...")
      ]
      # progress bar caption
      if Mode.normal
        # progress line
        Progress.New(
          _("Saving Boot Loader Configuration"),
          " ",
          stages.size,
          stages,
          titles,
          ""
        )
        Progress.NextStage
      else
        Progress.Title(titles[0])
      end

      params_to_save = {}
      ret = write_initrd(params_to_save)

      log.error "Error occurred while creating initrd" unless ret

      if Mode.normal
        Progress.NextStage
      else
        Progress.NextStep if !@repeating_write
        Progress.Title(titles[1])
      end

      ::Bootloader::BootloaderFactory.current.write

      true
    end

    # Write bootloader settings during installation
    # @return [Boolean] true on success
    def WriteInstallation
      log.info "Writing bootloader configuration during installation"

      mark_as_changed

      params_to_save = {}
      ret = write_initrd(params_to_save)

      log.error "Error occurred while creating initrd" unless ret

      write_sysconfig
      write_proposed_params(params_to_save)

      return ret if getLoaderType == "none"

      # F#300779 - Install diskless client (NFS-root)
      # kokso: bootloader will not be installed
      if BootStorage.disks_with_boot_partition == "/dev/nfs"
        log.info "Bootloader::Write() -> Boot partition is nfs type, bootloader will not be installed."
        return ret
      end

      # F#300779 -end

      # save bootloader settings
      reinit = !(Mode.update || Mode.normal)
      log.info "Reinitialize bootloader library before saving: #{reinit}"

      ret = blSave(true, reinit, true) && ret

      log.eror "Error before configuration files saving finished" unless ret

      # call bootloader executable
      log.info "Calling bootloader executable"
      ret &&= blWrite
      ret = handle_failed_write unless ret

      ret
    end

    # return default section label
    # @return [String] default section label
    def getDefaultSection
      ReadOrProposeIfNeeded()

      ""
      # FIXME: use bootloader factory to get it
    end

    FLAVOR_KERNEL_LINE_MAP = {
      :common    => "append",
      :xen_guest => "xen_append",
      :xen_host  => "xen_kernel_append"
    }

    # Gets value for given parameter in kernel parameters for given flavor.
    # @param [Symbol] flavor flavor of kernel, for possible values see #modify_kernel_param
    # @param [String] key of parameter on kernel command line
    # @returns [String,:missing,:present] Returns string for parameters with value,
    #   `:missing` if key is not there and `:present` for parameters without value.
    #
    # @example get crashkernel parameter to common kernel
    #   Bootloader.kernel_param(:common, "crashkernel")
    #   => "256M@64B"
    #
    # @example get cio_ignore parameter for xen_host kernel when missing
    #   Bootloader.kernel_param(:xen_host, "cio_ignore")
    #   => :missing
    #
    # @example get verbose parameter for xen_guest which is there
    #   Bootloader.kernel_param(:xen_guest, "verbose")
    #   => :present
    #

    def kernel_param(flavor, key)
      if flavor == :recovery
        log.warn "Using deprecated recovery flavor"
        return :missing
      end

      ReadOrProposeIfNeeded() # ensure we have some data

      current_bl = ::Bootloader::BootloaderFactory.current
      # currently only grub2 bootloader supported
      return :missing unless current_bl.respond_to?(:grub_default)
      grub_default = current_bl.grub_default
      params = case flavor
               when :common then grub_default.kernel_params
               when :xen_guest then grub_default.xen_kernel_params
               when :xen_host then grub_default.xen_hypervisor_params
               else raise ArgumentError, "Unknown flavor #{flavor}"
               end

      res = params.parameter(key)

      BOOLEAN_MAPPING[res] || res
    end

    # Modify kernel parameters for installed kernels according to values
    # @param [Array]  args parameters to modify. Last parameter is hash with keys
    #   and its values, keys are strings and values are `:present`, `:missing` or
    #   string value. Other parameters specify which kernel flavors are affected.
    #   Known values are:
    #     - `:common` for non-specific flavor
    #     - `:recovery` DEPRECATED: no longer use
    #     - `:xen_guest` for xen guest kernels
    #     - `:xen_host` for xen host kernels
    # @return [Boolean] true if params were modified; false otherwise.
    #
    # @example add crashkernel parameter to common kernel and xen guest
    #   Bootloader.modify_kernel_params(:common, :xen_guest, "crashkernel" => "256M@64M")
    #
    # @example same as before just with array passing
    #   targets = [:common, :xen_guest]
    #   Bootloader.modify_kernel_params(targets, "crashkernel" => "256M@64M")
    #
    # @example remove cio_ignore parameter for common kernel only
    #   Bootloader.modify_kernel_params("cio_ignore" => :missing)
    #
    # @example add cio_ignore parameter for xen host kernel
    #   Bootloader.modify_kernel_params(:xen_host, "cio_ignore" => :present)
    #
    def modify_kernel_params(*args)
      current_bl = ::Bootloader::BootloaderFactory.current
      # currently only grub2 bootloader supported
      return :missing unless current_bl.respond_to?(:grub_default)
      grub_default = current_bl.grub_default

      values = args.pop
      if !values.is_a? Hash
        raise ArgumentError, "Missing parameters to modify #{args.inspect}"
      end
      args = [:common] if args.empty? # by default change common kernels only
      args = args.first if args.first.is_a? Array # support array like syntax

      if args.include?(:recovery)
        args.delete(:recovery)
        log.warn "recovery flavor is deprecated and not set"
      end

      remap_values = BOOLEAN_MAPPING.invert
      values.each_key do |key|
        values[key] = remap_values[values[key]] if remap_values.key?(values[key])
      end

      params = args.map do |flavor|
        case flavor
        when :common then grub_default.kernel_params
        when :xen_guest then grub_default.xen_kernel_params
        when :xen_host then grub_default.xen_hypervisor_params
        else raise ArgumentError, "Unknown flavor #{flavor}"
        end
      end

      changed = false
      values.each do |key, value|
        params.each do |param|
          old_val = param.parameter(key)
          next if old_val == value

          changed = true
          # at first clean old entries
          matcher = CFA::Matcher.new(key: key)
          param.remove_parameter(matcher)

          case value
          when false then next # already done
          when true then param.add_parameter(key, value)
          when Array
            value.each { |val| param.add_parameter(key, val) }
          else
            param.add_parameter(key, value)
          end
        end
      end

      changed
    end

    # Get currently used bootloader, detect if not set yet
    # @return [String] botloader type
    def getLoaderType
      ::Bootloader::BootloaderFactory.current.name
    end

    # Set section to boot on next reboot
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagOnetimeBoot(section)
      blFlagOnetimeBoot(section)
    end

    # Check whether settings were read or proposed, if not, decide
    # what to do and read or propose settings
    def ReadOrProposeIfNeeded
      current_bl = ::Bootloader::BootloaderFactory.current
      return if current_bl.read? || current_bl.proposed?

      if Mode.config
        log.info "Initialize libstorage in readonly mode" # bnc#942360
        Storage.InitLibstorage(true)
        log.info "Not reading settings in Mode::config ()"
        Propose()
      elsif Stage.initial && !Mode.update
        Propose()
      else
        progress_orig = Progress.set(false)
        Read()
        Progress.set(progress_orig)
      end
    end

  private

    def mark_as_changed
      # always run mkinitrd at the end of S/390 installation (bsc#933177)
      # otherwise cio_ignore settings are not honored in initrd
      Initrd.changed = true if Arch.s390 && Stage.initial
    end

    def handle_failed_write
      log.error "Installing bootloader failed"
      if writeErrorPopup
        @repeating_write = true
        res = WFM.call("bootloader_proposal", ["AskUser", { "has_next" => false }])
        return Write() if res["workflow_sequence"] == :next
      end

      false
    end

    NONSPLASH_VGA_VALUES = ["", "false", "ask"]

    # store new vgamode if needed and regenerate initrd in such case
    # @param params_to_save used to store predefined vgamode value
    # @return boolean if succeed
    def write_initrd(_params_to_save)
      ret = true
      # TODO: detect VGA change
      #      new_vga = BootCommon.globals["vgamode"]
      #      if (new_vga != @old_vga && !NONSPLASH_VGA_VALUES.include?(new_vga)) ||
      #          !Mode.normal
      #        Initrd.setSplash(new_vga)
      #        params_to_save["vgamode"] = new_vga if Stage.initial
      #      end

      # save initrd
      ret = Initrd.Write if Initrd.changed

      ret
    end

    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Reset, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :FlagOnetimeBoot, :type => "boolean (string)"
    publish :function => :getDefaultSection, :type => "string ()"
    publish :function => :getLoaderType, :type => "string ()"
    publish :variable => :proposed_cfg_changed, :type => "boolean"
    publish :function => :blRead, :type => "boolean (boolean, boolean)"
    publish :function => :blSave, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :blWidgetMaps, :type => "map <string, map <string, any>> ()"
    publish :function => :blDialogs, :type => "map <string, symbol ()> ()"
    publish :variable => :test_abort, :type => "boolean ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Update, :type => "boolean ()"
    publish :function => :WriteInstallation, :type => "boolean ()"
  end

  Bootloader = BootloaderClass.new
  Bootloader.main
end
