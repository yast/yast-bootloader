# frozen_string_literal: true

require "yast"
require "y2storage"

Yast.import "BootStorage"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Mode"

require "bootloader/device_map"

module Bootloader
  # Represents dialog for modification of device map
  class DeviceMapDialog
    include Yast::UIShortcuts
    include Yast::I18n

    def self.run(device_map)
      new(device_map).run
    end

    def initialize(device_map)
      @device_map = device_map
    end

    def run
      textdomain "bootloader"

      return unless create_dialog

      begin
        controller_loop
      ensure
        close_dialog
      end
    end

  private

    def create_dialog
      res = Yast::UI.OpenDialog dialog_content
      return false unless res

      refresh_buttons

      true
    end

    def close_dialog
      Yast::UI.CloseDialog
    end

    def controller_loop
      loop do
        input = Yast::UI.UserInput
        pos = selected_disk_index
        case input
        when :ok
          if disks.empty?
            Yast::Popup.Error(_("Device map must contain at least one device"))
            next
          end
          max_dev = Bootloader::DeviceMap::BIOS_LIMIT
          if disks.size > max_dev
            # TRANSLATORS: an error message where %i is the number of devices.
            Yast::Popup.Error(_("Device map can have at maximum %i devices") % max_dev)
            next
          end
          store_order
          return :back # we just go back to original dialog
        when :cancel
          return :back
        when :up, :down, :delete, :add
          pos = handle_buttons(input, pos)
        when :disks
          refresh_buttons
          next
        else
          raise "Unknown action #{input}"
        end
        refresh_disks
        Yast::UI.ChangeWidget(Id(:disks), :CurrentItem, disks[pos])
        refresh_buttons
      end
    end

    def handle_buttons(action, pos)
      case action
      when :up
        disks.insert(pos - 1, disks.delete_at(pos))
        pos -= 1
      when :down
        disks.insert(pos + 1, disks.delete_at(pos))
        pos += 1
      when :delete
        disks.delete_at(pos)
        pos = (pos == disks.size) ? pos - 1 : pos
      when :add
        disks_to_add = if Yast::Mode.config || Yast::Mode.auto
          add_device_popup_ay_mode
        else
          add_devices_popup
        end
        disks.concat disks_to_add
        pos = disks.size - 1
      end

      pos
    end

    def dialog_content
      VBox(
        headings,
        VSpacing(1),
        contents,
        VSpacing(1),
        ending_buttons
      )
    end

    def headings
      Heading(_("Disk order settings"))
    end

    def contents
      HBox(
        VBox(
          SelectionBox(Id(:disks), Opt(:notify), _("D&isks"), disks),
          # make dialog reasonable big, but increace mainly selection box which contain device names
          HSpacing(60)
        ),
        action_buttons
      )
    end

    def action_buttons
      VBox(
        PushButton(Id(:add), Opt(:key_F3), Yast::Label.AddButton),
        PushButton(Id(:delete), Opt(:key_F5), Yast::Label.DeleteButton),
        VSpacing(1),
        PushButton(Id(:up), Opt(:hstretch), Yast::Label.UpButton),
        PushButton(Id(:down), Opt(:hstretch), Yast::Label.DownButton),
        VStretch()
      )
    end

    def ending_buttons
      ButtonBox(
        PushButton(Id(:ok), Yast::Label.OKButton),
        PushButton(Id(:cancel), Yast::Label.CancelButton)
      )
    end

    def disks
      @disks ||= @device_map.disks_order
    end

    def refresh_disks
      Yast::UI.ChangeWidget(Id(:disks), :Items, disks)
    end

    def available_devices
      staging = Y2Storage::StorageManager.instance.staging
      staging.disk_devices.map(&:name)
    end

    def store_order
      @device_map.clear_mapping
      disks.each_with_index do |disk, index|
        @device_map.add_mapping("hd#{index}", disk)
      end
    end

    def add_device_popup_ay_mode
      popup = VBox(
        VSpacing(1),
        # textentry header
        InputField(Id(:devname), Opt(:hstretch), _("&Device")),
        VSpacing(1),
        ButtonBox(
          PushButton(Id(:ok), Opt(:key_F10, :default), Yast::Label.OKButton),
          PushButton(Id(:cancel), Opt(:key_F8), Yast::Label.CancelButton)
        ),
        VSpacing(1)
      )
      Yast::UI.OpenDialog(popup)
      Yast::UI.SetFocus(:devname)
      pushed = Yast::UI.UserInput
      new_dev = Yast::UI.QueryWidget(Id(:devname), :Value)
      Yast::UI.CloseDialog

      (pushed == :ok) ? [new_dev] : []
    end

    def add_devices_popup
      devices = available_devices - disks
      popup = VBox(
        MultiSelectionBox(
          Id(:devnames),
          _("&Devices:"),
          devices
        ),
        ending_buttons,
        VSpacing(1)
      )
      Yast::UI.OpenDialog(popup)
      Yast::UI.SetFocus(:devnames)
      pushed = Yast::UI.UserInput
      new_devs = Yast::UI.QueryWidget(Id(:devnames), :SelectedItems)
      Yast::UI.CloseDialog

      (pushed == :ok) ? new_devs : []
    end

    def selected_disk_index
      disks.index(Yast::UI.QueryWidget(Id(:disks), :CurrentItem))
    end

    def refresh_buttons
      # by default enable delete and later disable if there are no disks
      Yast::UI.ChangeWidget(Id(:delete), :Enabled, true)
      pos = selected_disk_index
      if !pos # nothing selected
        disk_to_select = disks.first
        # there is no disks
        if !disk_to_select
          up_down_enablement(false, false)
          Yast::UI.ChangeWidget(Id(:delete), :Enabled, false)
          return
        end
        Yast::UI.ChangeWidget(Id(:disks), :CurrentItem, disk_to_select)
        refresh_buttons
        return
      end

      up_down_enablement(pos > 0, pos < (disks.size - 1))
    end

    def up_down_enablement(up_enabled, down_enabled)
      Yast::UI.ChangeWidget(Id(:up), :Enabled, up_enabled)
      Yast::UI.ChangeWidget(Id(:down), :Enabled, down_enabled)
    end
  end
end
