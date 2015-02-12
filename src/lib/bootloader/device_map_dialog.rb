require "yast"

Yast.import "BootCommon"
Yast.import "BootStorage"
Yast.import "Label"
Yast.import "Popup"

require "bootloader/device_map"

module Bootloader
  # Represents dialog for modification of device map
  class DeviceMapDialog
    include Yast::UIShortcuts
    include Yast::I18n

    def self.run
      new.run
    end

    def run
      textdomain "bootloader"

      return unless create_dialog

      begin
        return controller_loop
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
          store_order
          return :back # we just go back to original dialog
        when :cancel
          return :back
        when :up
          disks.insert(pos - 1, disks.delete_at(pos))
          pos -= 1
        when :down
          disks.insert(pos + 1, disks.delete_at(pos))
          pos += 1
        when :delete
          disks.delete_at(pos)
          pos = pos == disks.size ? pos - 1 : pos
        when :add
          disk = add_device_popup
          disks << disk if disk
          pos = disks.size - 1
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
        SelectionBox(Id(:disks), Opt(:notify), _("D&isks"), disks),
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
      @disks ||= Yast::BootStorage.DisksOrder
    end

    def refresh_disks
      Yast::UI.ChangeWidget(Id(:disks), :Items, disks)
    end

    def store_order
      Yast::BootCommon.mbrDisk = disks.first

      mapping = disks.each_with_object({}) do |disk, res|
        res[disk] = "hd#{res.size}"
      end

      Yast::BootStorage.device_map = ::Bootloader::DeviceMap.new(mapping)
    end

    def add_device_popup
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

      pushed == :ok ? new_dev : nil
    end

    def selected_disk_index
      disks.index(Yast::UI.QueryWidget(Id(:disks), :CurrentItem))
    end

    def refresh_buttons
      pos = selected_disk_index
      if !pos # nothing selected
        disk_to_select = disks.first
        # there is no disks
        if !disk_to_select
          up_down_enablement(false, false)
          return
        end
        Yast::UI.ChangeWidget(Id(:disks), :CurrentItem, disk_to_select)
        refresh_buttons
        return
      end

      up_down_enablement(pos > 0, pos < (disks.size - 1))
    end

    def up_down_enablement(up, down)
      Yast::UI.ChangeWidget(Id(:up), :Enabled, up)
      Yast::UI.ChangeWidget(Id(:down), :Enabled, down)
    end
  end
end
