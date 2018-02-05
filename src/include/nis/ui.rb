# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:
#   include/nis/ui.ycp
#
# Package:
#   Configuration of NIS
#
# Summary:
#   User interface functions.
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# All user interface functions.
#
module Yast
  module NisUiInclude
    def initialize_nis_ui(include_target)
      Yast.import "UI"
      textdomain "nis"

      Yast.import "Autologin"
      Yast.import "Confirm"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "NetworkService"
      Yast.import "Nis"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Sequencer"
      Yast.import "Stage"
      Yast.import "Wizard"

      #const
      @broadcast_help =
        # Translators: network broadcast address
        _(
          "<p>The <b>Broadcast</b> option enables searching\n" +
            "in the local network to find a server after the specified servers\n" +
            "fail to respond. It is a security risk.</p>\n"
        )

      #const
      @expert_help =
        # Translators: short for Expert settings
        _(
          "<p><b>Expert</b> gives access to some\nless frequently used settings.</p>\n"
        )

      # A cache of NIS servers found on the LAN for each domain.
      # @see #SelectNisServers
      @found_servers = {} # map <string, list <string> >

      @check_g = nil

      @Dialogs = {
        "main"        => lambda { MainDialog() },
        "additional"  => lambda { AdditionalDialog() },
        "expert"      => lambda { ExpertDialog() },
        "common-next" => [lambda { JustNext() }, true],
        "end"         => lambda { SaveDialog() }
      }

      @Sequence = {
        "ws_start"    => "main",
        "main"        => {
          :next   => "common-next",
          :expert => "expert",
          :edit   => "additional",
          :abort  => :abort
        },
        "additional"  => { :next => "main", :abort => :abort },
        "expert"      => { :next => "main", :abort => :abort },
        # This is will make AutoSequence finish without
        # confirmation. NormalSequence overrides it.
        "common-next" => {
          :next => :next
        },
        "end"         => { :next => :next }
      }
    end

    # A Wizard Sequencer helper
    # @return	`next
    def JustNext
      :next
    end

    # The dialog that appears when the [Abort] button is pressed.
    # @param [Boolean] touched data modified?
    # @return `abort if user really wants to abort, `back otherwise
    def ReallyAbort(touched)
      touched || Stage.cont ? Popup.ReallyAbort(true) : true
    end

    # Let the user choose some of a list of items
    # @param [String] title	selectionbox title
    # @param [Array<String>] items	a list of items
    # @return		items or nil on cancel
    def ChooseItems(title, items)
      items = deep_copy(items)
      msb_items = Builtins.maplist(items) { |entry| Item(Id(entry), entry) }
      UI.OpenDialog(
        VBox(
          HSpacing(40),
          HBox(MultiSelectionBox(Id(:items), title, msb_items), VSpacing(10)),
          HBox(
            # pushbutton label
            # Select all items (in this case NIS servers) of a list
            PushButton(Id(:all), _("Select &All")),
            # pushbutton label
            # Deselect all items (in this case NIS servers) of a list
            PushButton(Id(:none), _("Select &None"))
          ),
          HBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          )
        )
      )
      UI.SetFocus(Id(:items))
      ret = nil
      begin
        ret = UI.UserInput
        if ret == :all
          UI.ChangeWidget(Id(:items), :SelectedItems, items)
        elsif ret == :none
          UI.ChangeWidget(Id(:items), :SelectedItems, [])
        end
      end while ret != :cancel && ret != :ok

      if ret == :ok
        items = Convert.convert(
          UI.QueryWidget(Id(:items), :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )
      else
        items = nil
      end
      UI.CloseDialog

      deep_copy(items)
    end

    # Scan the network for NIS servers and let the user select among them.
    # @param [String] domain which domain
    # @return space separated list of servers or ""
    def SelectNisServers(domain)
      Wizard.SetScreenShotName("nis-client-2a1-servers")
      if Mode.screen_shot
        Ops.set(
          @found_servers,
          domain,
          ["nis.example.com", "10.42.1.1", "10.42.1.2"]
        )
      end

      if !Builtins.haskey(@found_servers, domain)
        # popup window
        # LAN: local area network
        UI.OpenDialog(
          Label(
            Builtins.sformat(
              _("Scanning for NIS servers in domain %1 on this LAN..."),
              domain
            )
          )
        )
        Ops.set(
          @found_servers,
          domain,
          SCR.Read(Builtins.add(path(".net.ypserv.find"), domain))
        )
        UI.CloseDialog
        if Ops.get(@found_servers, domain) == nil
          Ops.set(@found_servers, domain, ["internal-error"])
        end
      end

      selected_servers =
        # selection box label
        ChooseItems(
          Builtins.sformat(_("&NIS Servers in Domain %1"), domain),
          Ops.get_list(@found_servers, domain, [])
        )
      Builtins.y2milestone("selected_servers: %1", selected_servers)
      selected_servers = [] if selected_servers == nil
      Wizard.RestoreScreenShotName
      Builtins.mergestring(selected_servers, " ")
    end

    # The simple dialog
    # @return	`back, `abort, `next, `multiple or `expert
    def MainDialog
      Wizard.SetScreenShotName("nis-client-2a-single")

      firewall_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        {
          "services"        => ["ypbind"],
          "display_details" => true,
          # firewall opening help
          "help"            => _(
            "<p><b>Firewall Settings</b><br>\n" +
              "To open the firewall to allow accessing the 'ypbind' service\n" +
              "from remote computers, set <b>Open Port in Firewall</b>.\n" +
              "To select interfaces on which to open the port, click <b>Firewall Details</b>.\n" +
              "This option is only available if the firewall is enabled.</p>\n"
          )
        }
      )
      firewall_layout = firewall_widget["custom_widget"] || VBox()

      # help text
      help_text = _(
        "<p>Enter your NIS domain, such as example.com,\n and the NIS server's address, such as nis.example.com or 10.20.1.1.</p>\n"
      ) +
        # help text for netconfig part
        _(
          "<p>Select the way how the NIS configuration will be modified. Normally, it is\n" +
            "handled by the netconfig script, which merges the data statically defined here\n" +
            "with dynamically obtained data (e.g. from DHCP client, NetworkManager\n" +
            "etc.). This is the Default Policy and sufficient for most configurations. \n" +
            "By choosing Only Manual Changes, netconfig will no longer be allowed to modify\n" +
            "the configuration. You can, however, edit the file manually. By choosing\n" +
            "Custom Policy, you can specify a custom policy string, which consists of a\n" +
            "space-separated list of interface names, including wildcards, with\n" +
            "STATIC/STATIC_FALLBACK as predefined special values. For more information, see\n" +
            "the netconfig manual page.</p>\n"
        )

      # help text
      help_text = Ops.add(
        help_text,
        _(
          "<p>Specify multiple servers\nby separating their addresses with spaces.</p>\n"
        )
      )

      help_text = Ops.add(help_text, @broadcast_help)

      # help text
      help_text = Ops.add(
        Ops.add(
          help_text,
          _(
            "<p><b>Automounter</b> is a daemon that mounts directories automatically,\n" +
              "such as users' home directories.\n" +
              "It is assumed that its configuration files (auto.*) already exist,\n" +
              "either locally or over NIS.</p>"
          )
        ),
        # help text
        _(
          "<p>NFS Settings which affects how the automounter operates could be set in NFS Client, which can be configured using <b>NFS Configuration</b> button.</p>"
        )
      )


      help_text = Ops.add(
        help_text,
        Ops.get_string(firewall_widget, "help", "")
      )


      domain = Nis.GetDomain
      servers = Nis.GetServers

      # In this simple case, let's discard the distinction.
      default_broadcast = Nis.default_broadcast || Nis.global_broadcast

      # the default is the current status
      # or true in case we were called during the installation
      yp_client = Nis.start
      if Stage.cont && !Builtins.contains(WFM.Args, "from_users")
        yp_client = true
      end
      autofs = Nis._start_autofs
      all_servers = Builtins.mapmap(Nis.multidomain_servers) do |d, s|
        {
          d => [
            s,
            Ops.get(Nis.multidomain_broadcast, d, false),
            Ops.get_boolean(Nis.slp_domain, d, false)
          ]
        }
      end

      all_servers = Builtins.add(
        all_servers,
        "",
        [Nis.servers, Nis.default_broadcast]
      )

      additional_domains = []

      Builtins.foreach(all_servers) do |d, s|
        if d != nil && d != ""
          additional_domains = Builtins.add(additional_domains, d)
        end
      end

      Builtins.y2debug("all_servers: %1", all_servers)
      Builtins.y2debug("additional_domains: %1", additional_domains)

      automatic_label = NetworkService.is_network_manager ?
        # radio button label
        _("Au&tomatic Setup (Via NetworkManager and DHCP)") :
        # radio button label
        _("Au&tomatic Setup (via DHCP)")

      text_mode = Ops.get_boolean(UI.GetDisplayInfo, "TextMode", false)

      con = nil
      # frame label
      nis_frame = Frame(
        _("NIS client"),
        HBox(
          HSpacing(0.4),
          VBox(
            VSpacing(0.2),
            HBox(
              ComboBox(
                Id(:policy),
                Opt(:notify),
                # combo box label
                _("Netconfig NIS &Policy"),
                [
                  # combo box item
                  Item(Id(:nomodify), _("Only Manual Changes")),
                  # combo box item
                  Item(Id(:auto), _("Default Policy")),
                  # combo box item
                  Item(Id(:custom), _("Custom Policy"))
                ]
              ),
              HSpacing(),
              InputField(
                Id(:custompolicy),
                Opt(:hstretch),
                # text entry label
                _("C&ustom Policy"),
                ""
              )
            ),
            VSpacing(0.2),
            text_mode ?
              HBox(
                InputField(
                  Id(:domain),
                  Opt(:hstretch),
                  _("N&IS Domain"),
                  domain
                ),
                HSpacing(),
                InputField(
                  Id(:servers),
                  Opt(:hstretch),
                  _("&Addresses of NIS servers"),
                  servers
                )
              ) :
              VBox(
                # text entry label
                InputField(
                  Id(:domain),
                  Opt(:hstretch),
                  _("N&IS Domain"),
                  domain
                ),
                VSpacing(0.2),
                InputField(
                  Id(:servers),
                  Opt(:hstretch),
                  # text entry label
                  _("&Addresses of NIS servers"),
                  servers
                )
              ),
            HBox(
              # check box label
              Left(
                CheckBox(
                  Id(:broadcast),
                  Opt(:notify),
                  _("&Broadcast"),
                  default_broadcast
                )
              ),
              # pushbutton label, find nis servers
              # Shortcut must not conflict with Finish and Next (#29960)
              Right(PushButton(Id(:find), _("Fin&d")))
            ),
            HBox(
              VBox(
                Left(Label(_("Additional NIS Domains"))),
                HBox(
                  HSpacing(1),
                  Label(
                    Id(:adddomains),
                    Opt(:outputField, :hstretch),
                    Builtins.mergestring(additional_domains, ", ")
                  )
                )
              ),
              HSpacing(1.2),
              VBox(
                Label(""),
                # button label
                PushButton(Id(:edit), _("&Edit"))
              )
            ),
            VSpacing(0.3)
          ),
          HSpacing(0.4)
        )
      )

      con = HBox(
        HSpacing(0.5),
        VCenter(
          VBox(
            VSpacing(0.4),
            RadioButtonGroup(
              Id(:rd),
              Left(
                HVSquash(
                  VBox(
                    Left(
                      RadioButton(
                        Id(:nisno),
                        Opt(:notify),
                        # radio button label
                        _("Do &not use NIS"),
                        !yp_client
                      )
                    ),
                    Left(
                      RadioButton(
                        Id(:nisyes),
                        Opt(:notify),
                        # radio button label
                        _("&Use NIS"),
                        yp_client
                      )
                    )
                  )
                )
              )
            ),
            VSpacing(0.4),
            nis_frame,
            VSpacing(0.4),
            HBox(
                 HSquash(firewall_layout),
                 HSpacing(0.8),
                 VBox(
                      VSpacing(0.8),
                      HBox(
                           PushButton(
                                      Id(:expert),
                                      Opt(:key_F7),
                                      # button label (short for Expert settings)
                                      _("E&xpert...")
                                      ),
                           PushButton(
                                      Id(:nfs),
                                      Opt(:key_F8),
                                      # button label
                                      _("NFS Configuration...")
                                      )
                           ),
                      # check box label
                      CheckBox(Id(:autofs), _("Start Auto&mounter"), autofs)
                      )
                 )
            )
        )
      )

      Wizard.SetContentsButtons(
        # dialog title
        _("Configuration of NIS client"),
        con,
        help_text,
        Label.BackButton,
        Stage.cont ? Label.NextButton : Label.FinishButton
      )
      Wizard.RestoreAbortButton

      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")

      UI.ChangeWidget(Id(:autofs), :Enabled, Nis._autofs_allowed)

      if Nis.policy == ""
        UI.ChangeWidget(Id(:policy), :Value, Id(:nomodify))
        UI.ChangeWidget(Id(:custompolicy), :Enabled, false)
      elsif Nis.policy == "auto" || Nis.policy == "STATIC *"
        UI.ChangeWidget(Id(:policy), :Value, Id(:auto))
        UI.ChangeWidget(Id(:custompolicy), :Enabled, false)
      else
        UI.ChangeWidget(Id(:policy), :Value, Id(:custom))
        UI.ChangeWidget(Id(:custompolicy), :Enabled, true)
        UI.ChangeWidget(Id(:custompolicy), :Value, Nis.policy)
      end
      event = {}
      result = nil
      begin
        Builtins.y2milestone("LOOP: %1", result)
        yp_client = UI.QueryWidget(Id(:rd), :CurrentButton) != :nisno
        UI.ChangeWidget(Id(:expert), :Enabled, yp_client)
        UI.ChangeWidget(Id(:policy), :Enabled, yp_client)
        #UI::ChangeWidget (`id (`custompolicy), `Enabled, yp_client);
        UI.ChangeWidget(Id(:autofs), :Enabled, yp_client)
        UI.ChangeWidget(Id(:nfs), :Enabled, yp_client)

        manual = UI.QueryWidget(Id(:policy), :Value) == :nomodify
        UI.ChangeWidget(Id(:domain), :Enabled, !manual && yp_client)
        UI.ChangeWidget(Id(:servers), :Enabled, !manual && yp_client)
        UI.ChangeWidget(Id(:broadcast), :Enabled, !manual && yp_client)
        UI.ChangeWidget(Id(:find), :Enabled, !manual && yp_client)
        UI.ChangeWidget(Id(:edit), :Enabled, !manual && yp_client)
        UI.ChangeWidget(Id(:adddomains), :Enabled, !manual && yp_client)

        if result == :policy
          mode = Convert.to_symbol(UI.QueryWidget(Id(:policy), :Value))
          Builtins.y2milestone("mode: %1", mode)
          if mode == :nomodify || mode == :auto
            Builtins.y2milestone("Disable custompolicy")
            UI.ChangeWidget(Id(:custompolicy), :Value, "")
            UI.ChangeWidget(Id(:custompolicy), :Enabled, false)
          else
            Builtins.y2milestone("Enable custompolicy")
            UI.ChangeWidget(Id(:custompolicy), :Value, Nis.policy)
            UI.ChangeWidget(Id(:custompolicy), :Enabled, true && yp_client)
          end
        end
        event = UI.WaitForEvent
        result = Ops.get_symbol(event, "ID")
        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)

        result = :abort if result == :cancel

        if result == :find
          domain = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))
          if domain == ""
            # Message popup. The user wants to Find servers
            # but the domain is unknown.
            Popup.Message(
              _("Finding servers works only when the domain is known.")
            )
            UI.SetFocus(Id(:domain))
          else
            servers2 = SelectNisServers(domain)
            UI.ChangeWidget(Id(:servers), :Value, servers2) if servers2 != ""
          end
        elsif result == :nfs
          if Package.InstallAll(["yast2-nfs-client"])
            WFM.CallFunction("nfs-client", [])
          end
        elsif Builtins.contains([:next, :edit, :expert], result)
          yp_client = Convert.to_symbol(UI.QueryWidget(Id(:rd), :CurrentButton)) != :nisno

          # Using NIS and LDAP simultaneously is not supported (#36981).
          if result == :next && yp_client && !Nis.start && Nis.UsersByLdap
            # yes-no popup
            if !Popup.YesNo(
                _(
                  "When you configure your machine as a NIS client,\n" +
                    "you cannot retrieve the user data from LDAP.\n" +
                    "Are you sure?"
                )
              )
              result = nil
              next
            end
          end

          if UI.QueryWidget(Id(:policy), :Value) == :custom
            Nis.policy = Convert.to_string(
              UI.QueryWidget(Id(:custompolicy), :Value)
            )
          elsif UI.QueryWidget(Id(:policy), :Value) == :auto
            Nis.policy = "auto"
          else
            Nis.policy = ""
          end
          domain = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))
          servers = Convert.to_string(UI.QueryWidget(Id(:servers), :Value))
          default_broadcast = Convert.to_boolean(
            UI.QueryWidget(Id(:broadcast), :Value)
          )

          if yp_client && !manual && domain != "" &&
              !Nis.check_nisdomainname(domain)
            UI.SetFocus(Id(:domain))
            Popup.Error(Nis.valid_nisdomainname)
            result = nil
            next
          end

          temp_ad = Builtins.filter(Builtins.splitstring(servers, " ")) do |a|
            a != ""
          end

          if yp_client && !manual && !default_broadcast && servers != "" &&
              (Builtins.size(temp_ad) == 0 || Builtins.find(temp_ad) do |a|
                !Nis.check_address_nis(a)
              end != nil)
            UI.SetFocus(Id(:servers))
            Popup.Message(Nis.valid_address_nis)
            result = nil
            next
          end
          if result == :next
            CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)
          end
        end
      end until result == :edit || result == :next || result == :expert ||
        result == :abort && ReallyAbort(Nis.touched) ||
        result == :back && (Stage.cont || ReallyAbort(Nis.touched))

      if Builtins.contains([:next, :expert, :edit], result)
        Nis.Touch(Nis.start != yp_client)
        Nis.start = yp_client
        Nis.dhcp_restart = false
        Nis.SetDomain(domain)
        Nis.SetServers(servers)
        Nis.Touch(Nis.default_broadcast != default_broadcast)
        Nis.default_broadcast = default_broadcast
        Nis.Touch(Nis.global_broadcast != false)
        Nis.global_broadcast = false

        newautofs = Nis._autofs_allowed &&
          Convert.to_boolean(UI.QueryWidget(Id(:autofs), :Value))
        Nis.Touch(Nis._start_autofs != newautofs)
        Nis._start_autofs = newautofs
      end

      Wizard.RestoreScreenShotName
      result
    end


    # The expert dialog
    # @return	`back, `abort or `next
    def ExpertDialog
      Wizard.SetScreenShotName("nis-client-2c-expert")

      # help text 1/4
      help_text = _(
        "<p>Normally, it is possible for any host to query which server a client is using. Disabling <b>Answer Remote Hosts</b> restricts this only to the local host.</p>"
      )

      # help text 2/4
      # Check, ie. turn on a check box
      help_text = Ops.add(
        help_text,
        _(
          "<p>Check <b>Broken server</b> if answers from servers running on an unprivileged port should be accepted. It is a security risk and it is better to replace such a server.</p>"
        )
      )

      # help text 3/4
      help_text = Ops.add(
        help_text,
        _("<p>See <b>man ypbind</b> for details on other options.</p>")
      )

      local_only = Nis.local_only
      broken_server = Nis.broken_server
      options = Nis.options

      contents = HSquash(
        VBox(
          Frame(
            # frame label
            _("Expert settings"),
            VBox(
              VSpacing(0.2),
              # check box label
              Left(
                CheckBox(Id(:remote), _("Ans&wer Remote Hosts"), !local_only)
              ),
              # check box label
              Left(
                CheckBox(Id(:broken_server), _("Br&oken server"), broken_server)
              ),
              VSpacing(0.2),
              InputField(
                Id(:options),
                Opt(:hstretch),
                # text entry label (do not translate 'ypbind')
                _("Other &ypbind options"),
                options
              ),
              VSpacing(0.2)
            )
          ),
          VSpacing()
        )
      )

      Wizard.SetContentsButtons(
        # dialog title
        _("Expert settings"),
        contents,
        help_text,
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      event = {}
      result = nil
      begin
        event = UI.WaitForEvent
        result = Ops.get(event, "ID")

        result = :abort if result == :cancel

        if result == :next
          local_only = !Convert.to_boolean(UI.QueryWidget(Id(:remote), :Value))
          broken_server = Convert.to_boolean(
            UI.QueryWidget(Id(:broken_server), :Value)
          )
          # TODO: disallow " in options
          options = Convert.to_string(UI.QueryWidget(Id(:options), :Value))
        end
      end until result == :back || result == :next ||
        result == :abort && ReallyAbort(Nis.touched)

      if result == :next
        Nis.Touch(Nis.local_only != local_only)
        Nis.local_only = local_only
        Nis.Touch(Nis.broken_server != broken_server)
        Nis.broken_server = broken_server
        Nis.Touch(Nis.options != options)
        Nis.options = options
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(result)
    end
    # Constructs items for the domain table
    # @param [String] default_d	the default domain
    # @param [Hash{String => Array}] all_servers	map of {#server_sp}
    # @return a list of items
    # @see Nis#multidomain_servers TODO
    def DomainTableItems(default_d, all_servers)
      all_servers = deep_copy(all_servers)
      @check_g = UI.Glyph(:CheckMark) if @check_g == nil

      Builtins.y2debug("all_servers: %1", all_servers)
      # maps are sorted, so the default domain, "", comes first
      Builtins.maplist(all_servers) do |d, server_sp|
        Item(
          Id(d),
          d,
          # this would be a priority example x ]:
          Ops.get_boolean(server_sp, 1, false) ? @check_g : "",
          Ops.get_boolean(server_sp, 2, false) ? @check_g : "",
          Builtins.mergestring(Ops.get_list(server_sp, 0, []), ", ")
        )
      end
    end


    # @param [String] default_d	the default domain
    # @param [Hash{String => Array}] all_servers show these items
    # @param [String] d	the selected item
    def UpdateDomainTable(default_d, all_servers, d)
      all_servers = deep_copy(all_servers)
      UI.ChangeWidget(
        Id(:domains),
        :Items,
        DomainTableItems(default_d, all_servers)
      )
      UI.ChangeWidget(Id(:domains), :CurrentItem, d)

      nil
    end

    # @param [Hash] m	a map
    # @return		keys of the map
    def mapkeys(m)
      m = deep_copy(m)
      Builtins.maplist(m) { |k, v| k }
    end


    #
    # **Tuple:**
    #
    #     server_sp
    #      0 list(string)	server list
    #      1 boolean	broadcast

    # Add/Edit a domain, including its name and servers
    # @param [String] init		currently selected domain: nil=add, ""=default
    # @param [String] default_d	the default domain
    # @param [Array] server_sp	{#server_sp}
    # @param [Array<String>] existing	existing domains
    # @return [name, [ [server1, server2], broadcast? ]]
    def DomainPopup(init, default_d, server_sp, existing)
      server_sp = deep_copy(server_sp)
      existing = deep_copy(existing)
      Wizard.SetScreenShotName("nis-client-2b1-domain")

      domain = init == nil ? "" : init == "" ? default_d : init
      servers = Ops.get_list(server_sp, 0, [])
      servers_s = Builtins.mergestring(servers, "\n")
      broadcast = Ops.get_boolean(server_sp, 1, false)
      slp = Ops.get_boolean(server_sp, 2, false)

      t_servers = VBox(
        MultiLineEdit(
          Id(:servers),
          # Translators: multilineedit label
          # comma: ","
          _("&Servers (separated by spaces or commas)"),
          servers_s
        ),
        HBox(
          CheckBox(
            Id(:local_broadcast),
            # checkbox label
            _("&Broadcast"),
            broadcast
          ),
          CheckBox(
            Id(:slp),
            # checkbox label
            _("&SLP"),
            slp
          ),
          # pushbutton label, find nis servers
          # Shortcut must not conflict with Finish and Next (#29960)
          PushButton(Id(:find), _("Fin&d"))
        ),
        Empty()
      )

      contents = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.2),
          # Translators: popup dialog heading
          Heading(_("Domain Settings")),
          # Add a domain, Adding a domain? Edit...
          # Translators: text entry label
          Left(InputField(Id(:domain), _("&Domain name"), domain)),
          VSpacing(0.5),
          t_servers,
          VSpacing(0.2),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          ),
          VSpacing(0.2)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated), contents)
      UI.SetFocus(Id(:domain))

      ui = nil
      while true
        ui = UI.UserInput
        if ui == :cancel
          break
        elsif ui == :find
          domain = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))
          if domain == ""
            # Message popup. The user wants to Find servers
            # but the domain is unknown.
            Popup.Message(
              _("Finding servers works only when the domain is known.")
            )
            UI.SetFocus(Id(:domain))
          else
            servers2 = SelectNisServers(domain)
            UI.ChangeWidget(Id(:servers), :Value, servers2) if servers2 != ""
          end
        elsif ui == :ok
          # Input validation
          # all querywidgets done now for consistency
          domain = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))
          servers_s = Convert.to_string(UI.QueryWidget(Id(:servers), :Value))
          broadcast = Convert.to_boolean(
            UI.QueryWidget(Id(:local_broadcast), :Value)
          )
          slp = Convert.to_boolean(UI.QueryWidget(Id(:slp), :Value))

          servers = Builtins.splitstring(servers_s, ", \n")
          servers = Builtins.filter(servers) { |s| s != "" }
          bad_server = Builtins.find(servers) { |s| !Nis.check_address_nis(s) }

          if !Nis.check_nisdomainname(domain) #also disallows ""
            UI.SetFocus(Id(:domain))
            Popup.Error(Nis.valid_nisdomainname)
          elsif init != "" && domain != init &&
              Builtins.contains(existing, domain)
            UI.SetFocus(Id(:domain))
            # Translators: error message
            Popup.Error(_("This domain is already defined."))
          elsif bad_server != nil
            UI.SetFocus(Id(:servers))
            msg = Builtins.sformat(
              # Translators: error message
              _("The format of server address '%1' is not correct."),
              bad_server
            )
            Popup.Error(Ops.add(Ops.add(msg, "\n\n"), Nis.valid_address_nis))
          # check options (local broadcast and slp)
          elsif broadcast && slp
            UI.SetFocus(Id(:local_broadcast))
            # error message, 'Broadcast' and 'SLP' are checkboxes
            Popup.Error(
              _(
                "Enabling both Broadcast and SLP options\ndoes not make any sense. Select just one option."
              )
            )
          else
            # all checks OK, break the input loop
            break
          end
        end
      end

      UI.CloseDialog
      Wizard.RestoreScreenShotName
      ui == :ok ? [domain, [servers, broadcast, slp]] : nil
    end

    # The servers dialog
    # @return	`back, `abort or `next
    def AdditionalDialog
      Wizard.SetScreenShotName("nis-client-2b-multiple")

      # variable naming: _d means _domain, _s means _server
      all_servers = Builtins.mapmap(Nis.multidomain_servers) do |d, s|
        {
          d => [
            s,
            Ops.get(Nis.multidomain_broadcast, d, false),
            Ops.get_boolean(Nis.slp_domain, d, false)
          ]
        }
      end

      # help text
      help_text = _("<p>Specify the servers for additional domains.</p>")

      # help text
      help_text = Ops.add(help_text, @broadcast_help)

      # help text
      help_text = Ops.add(
        help_text,
        _(
          "<p>The Service Location Protocol (<b>SLP</b>) can be used to find NIS server.</p>"
        )
      )

      # "" means the default domain
      current_d = ""

      # build the dialog contents
      multiple = VBox(
        VSpacing(0.8),
        # dialog label
        Left(Label(_("Additional Domains"))),
        Table(
          Id(:domains),
          Opt(:notify, :immediate),
          Header(
            # table header
            _("Domain"),
            # table header
            Center(_("Broadcast")),
            # table header - Service Location Protocol
            Center(_("SLP")),
            # table header
            _("Servers")
          ),
          DomainTableItems(nil, all_servers)
        ),
        HBox(
          # button label
          PushButton(Id(:add_d), Opt(:key_F3), _("A&dd")),
          PushButton(Id(:edit_d), Opt(:key_F4), Label.EditButton),
          PushButton(Id(:del_d), Opt(:key_F5), Label.DeleteButton)
        ),
        VSpacing(1)
      )

      nis_vbox = VBox(VSpacing(0.2), multiple, VSpacing(0.2))

      nis_frame =
        # frame label
        Frame(_("NIS client"), nis_vbox)

      contents = deep_copy(nis_vbox)

      Wizard.SetContentsButtons(
        Builtins.sformat(
          "%1 - %2",
          # dialog title
          _("Configuration of NIS client"),
          # dialog subtitle
          _("Additional Domains")
        ),
        contents,
        help_text,
        Label.CancelButton,
        Label.OKButton
      )
      Wizard.HideAbortButton

      result = nil

      while true
        current_d = Convert.to_string(
          UI.QueryWidget(Id(:domains), :CurrentItem)
        )
        any_d = current_d != nil

        UI.ChangeWidget(Id(:edit_d), :Enabled, any_d)
        # deleting the defalut domain
        # actually deletes only the server list
        UI.ChangeWidget(
          Id(:del_d), #&& current_d !=""
          :Enabled,
          any_d
        )

        # Kludge, because a `Table still does not have a shortcut.
        # exclude textentry-notify
        UI.SetFocus(Id(:domains)) if result != :domain

        result = UI.UserInput
        result = :abort if result == :cancel

        # switch
        if result == :add_d
          name_servers = DomainPopup(
            nil,
            nil,
            [[], false],
            Convert.convert(
              mapkeys(all_servers),
              :from => "list",
              :to   => "list <string>"
            )
          )
          if name_servers != nil
            d = Ops.get_string(name_servers, 0)
            s_sp = Ops.get_list(name_servers, 1, [])
            all_servers = Builtins.add(all_servers, d, s_sp)
            # show these items, d selected
            UpdateDomainTable(nil, all_servers, d)
          end
        elsif result == :edit_d
          d0 = Convert.to_string(UI.QueryWidget(Id(:domains), :CurrentItem))

          if d0 != nil
            # editing the default domain is a special case
            name_servers = DomainPopup(
              d0,
              nil,
              Ops.get(all_servers, d0, []),
              Convert.convert(
                mapkeys(all_servers),
                :from => "list",
                :to   => "list <string>"
              )
            )
            if name_servers != nil
              d = Ops.get_string(name_servers, 0)
              s_sp = Ops.get_list(name_servers, 1, [])
              newkey = d0 == "" ? "" : d
              all_servers = Builtins.mapmap(all_servers) do |k, v|
                k == d0 ? { newkey => s_sp } : { k => v }
              end
              # show these items, d selected
              # TODO: if it flickers,
              #  only replace the old line by a new one
              UpdateDomainTable(nil, all_servers, newkey)
            end
          end
        elsif result == :del_d
          d0 = Convert.to_string(UI.QueryWidget(Id(:domains), :CurrentItem))
          if d0 != nil
            Wizard.SetScreenShotName("nis-client-2b-del-dom")
            # Translators: a yes-no popup
            if Popup.YesNo(_("Really delete this domain?"))
              all_servers = Builtins.filter(all_servers) { |k, v| k != d0 }
            end
            Wizard.RestoreScreenShotName
            # show these items, the default domain selected
            UpdateDomainTable(nil, all_servers, "")
          end
        elsif result == :back || result == :next ||
            result == :abort && ReallyAbort(Nis.touched)
          break
        end
      end

      if result == :next
        # add default server - it isn't displayed in the table
        all_servers = Builtins.add(
          all_servers,
          "",
          [Nis.servers, Nis.default_broadcast]
        )

        only_servers = Builtins.mapmap(all_servers) do |d, v|
          { d => Ops.get_list(v, 0, []) }
        end
        servers = Ops.get(only_servers, "", [])
        default_broadcast = nil
        multidomain_servers = nil
        multidomain_broadcast = nil

        only_broadcast = Builtins.mapmap(all_servers) do |d, v|
          { d => Ops.get_boolean(v, 1, false) }
        end
        default_broadcast = Ops.get(only_broadcast, "", false)
        multidomain_servers = Builtins.filter(only_servers) { |d, v| d != "" }
        multidomain_broadcast = Builtins.filter(only_broadcast) do |d, v|
          d != ""
        end

        slpdomain = Builtins.mapmap(all_servers) do |d, v|
          { d => Ops.get_boolean(v, 2, false) }
        end

        Nis.Touch(Nis.servers != servers)
        Nis.servers = deep_copy(servers)
        Nis.Touch(Nis.default_broadcast != default_broadcast)
        Nis.default_broadcast = default_broadcast
        Nis.Touch(Nis.slp_domain != slpdomain)
        Nis.slp_domain = deep_copy(slpdomain)
        Nis.Touch(false) #TODO need to know earlier for abort?
        Nis.multidomain_servers = deep_copy(multidomain_servers)
        Nis.Touch(false) #TODO need to know earlier for abort?
        Nis.multidomain_broadcast = deep_copy(multidomain_broadcast)
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(result)
    end

    # Confirmation dialog
    # Also probes for packages that need to be installed (autofs)
    # #23050 don't display the dialog
    # @return `back or `next
    def SaveDialog
      Wizard.SetScreenShotName("nis-client-3-save")

      message = Nis.ProbePackages

      Popup.Message(message) if message != ""

      Wizard.RestoreScreenShotName
      :next
    end

    # Dhcpcd writes yp.conf in the multidomain form.
    # Let's try rewriting it so that it fits into the simple dialog.
    # It is done only after read.
    def FitIntoSingle
      if Nis.policy != "" && Nis.dhcpcd_running
        d = Nis.GetDomain
        if Builtins.size(Nis.multidomain_servers) == 1
          s = Convert.convert(
            Ops.get(Nis.multidomain_servers, d, []),
            :from => "list",
            :to   => "list <string>"
          )
          # if there's only one entry, for the correct domain
          if Ops.greater_than(Builtins.size(s), 0)
            Builtins.y2milestone("Fitting into the simple dialog")
            Nis.servers = deep_copy(s)
            Nis.multidomain_servers = {}
            Nis.default_broadcast = Ops.get(Nis.multidomain_broadcast, d, false)
            Nis.multidomain_broadcast = {}
          end
        end
      end

      nil
    end

    # The normal workflow
    # @return `back, `abort or `next
    def NormalSequence
      normal_override = { "common-next" => { :next => "end" } }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("nis")

      # checking for root permissions (#158483)
      if !Confirm.MustBeRoot
        UI.CloseDialog
        return :abort
      end

      if Mode.screen_shot
        Nis.Fake
      else
        Nis.Read
      end

      FitIntoSingle()

      # the second map must override the first!
      result = Sequencer.Run(
        @Dialogs,
        Builtins.union(@Sequence, normal_override)
      )

      if result == :next
        if Nis.start
          # popup text FIXME better...
          Autologin.AskForDisabling(_("NIS is now enabled."))
        end

        # Install packages if needed.
        # Cannot do it in Write, autoinstall does it differently.
        if Ops.greater_than(Builtins.size(Nis.install_packages), 0)
          if !Package.DoInstallAndRemove(Nis.install_packages, [])
            Popup.Error(Message.FailedToInstallPackages)
          end
        end

        if Nis.Write
          if Nis.start && Nis.DomainChanged
            Popup.Warning(Message.DomainHasChangedMustReboot)
          end
        end
      end
      UI.CloseDialog
      result
    end

    # The autoinstallation workflow
    # @return `back, `abort or `next
    def AutoSequence
      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("nis")
      ret = Sequencer.Run(@Dialogs, @Sequence)
      UI.CloseDialog
      ret
    end
  end
end
