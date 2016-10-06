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
require "bootloader/exceptions"
require "bootloader/sysconfig"
require "bootloader/bootloader_factory"
require "bootloader/autoyast_converter"
require "cfa/matcher"

Yast.import "UI"
Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Initrd"
Yast.import "Mode"
Yast.import "Progress"
Yast.import "Report"
Yast.import "Stage"
Yast.import "Storage"
Yast.import "StorageDevices"

module Yast
  class BootloaderClass < Module
    include Yast::Logger

    BOOLEAN_MAPPING = { true => :present, false => :missing }.freeze

    def main
      textdomain "bootloader"

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
      Yast::BootStorage.detect_disks

      config = ::Bootloader::BootloaderFactory.current
      config.read if !config.read? && !config.proposed?
      result = ::Bootloader::AutoyastConverter.export(config)

      log.info "autoyast map for bootloader: #{result.inspect}"

      result
    end

    # Import settings from a map
    # @param [Hash] data map of bootloader settings
    # @return [Boolean] true on success
    def Import(data)
      # AutoYaST configuration mode. There is no access to the system
      Yast::BootStorage.detect_disks

      factory = ::Bootloader::BootloaderFactory

      imported_configuration = ::Bootloader::AutoyastConverter.import(data)
      factory.clear_cache

      proposed_configuration = factory.bootloader_by_name(imported_configuration.name)
      unless Mode.config # no AutoYaST configuration mode
        proposed_configuration.propose
        proposed_configuration.merge(imported_configuration)
      end
      factory.current = proposed_configuration

      true
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

      BootStorage.detect_disks

      Progress.NextStage
      return false if testAbort

      begin
        ::Bootloader::BootloaderFactory.current.read
      rescue ::Bootloader::UnsupportedBootloader => e
        ret = Yast::Report.AnyQuestion(_("Unsupported Bootloader"),
          _("Unsupported bootloader '%s' detected. Use proposal of supported configuration instead?") %
            e.bootloader_name,
          _("Use"),
          _("Quit"),
          :yes) # focus proposing new one
        return false unless ret

        ::Bootloader::BootloaderFactory.current = ::Bootloader::BootloaderFactory.proposed
        ::Bootloader::BootloaderFactory.current.propose
      end

      Progress.Finish

      true
    end

    # Reset bootloader settings
    def Reset
      return if Mode.autoinst
      log.info "Resetting configuration"

      ::Bootloader::BootloaderFactory.clear_cache
      if Stage.initial
        config = ::Bootloader::BootloaderFactory.proposed
        config.propose
      else
        config = ::Bootloader::BootloaderFactory.system
        config.read
      end
      ::Bootloader::BootloaderFactory.current = config
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
      if BootStorage.disk_with_boot_partition == "/dev/nfs"
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

      ret = write_initrd

      log.error "Error occurred while creating initrd" unless ret

      Progress.NextStep
      Progress.Title(titles[1]) unless Mode.normal

      ::Bootloader::BootloaderFactory.current.write

      true
    end

    # return default section label
    # @return [String] default section label
    def getDefaultSection
      ReadOrProposeIfNeeded()

      bootloader = Bootloader::BootloaderFactory.current
      return "" unless bootloader.respond_to?(:sections)
      bootloader.sections.default
    end

    FLAVOR_KERNEL_LINE_MAP = {
      :common    => "append",
      :xen_guest => "xen_append",
      :xen_host  => "xen_kernel_append"
    }.freeze

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
      ReadOrProposeIfNeeded() # ensure we have data to modify
      current_bl = ::Bootloader::BootloaderFactory.current
      # currently only grub2 bootloader supported
      return :missing unless current_bl.respond_to?(:grub_default)
      grub_default = current_bl.grub_default

      values = args.pop
      raise ArgumentError, "Missing parameters to modify #{args.inspect}" if !values.is_a? Hash

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

    NONSPLASH_VGA_VALUES = ["", "false", "ask"].freeze

    # store new vgamode if needed and regenerate initrd in such case
    # @param params_to_save used to store predefined vgamode value
    # @return boolean if succeed
    def write_initrd
      return true unless Initrd.changed

      # save initrd
      Initrd.Write
    end

    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Reset, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
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
