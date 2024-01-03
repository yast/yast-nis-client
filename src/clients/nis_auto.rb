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

# File:  clients/nis_auto.ycp
# Package:  nis-client configuration
# Summary:  client for autoinstallation
# Authors:  Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class NisAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "nis"

      Yast.import "Nis"
      Yast.include self, "nis/ui.rb"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("NIS client autoinst client started")
      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Import data
      case @func
      when "Import"
        @ret = Nis.Import(@param)
      # create a  summary
      when "Summary"
        @ret = Nis.Summary
      # ShortSummary is used by Users module
      when "ShortSummary"
        @ret = Nis.ShortSummary
      when "Reset"
        Nis.Import({})
        @ret = {}
      when "Change"
        @ret = AutoSequence()
      when "Read"
        @ret = Nis.Read
      when "GetModified"
        @ret = Nis.GetModified
      when "SetModified"
        Nis.SetModified
      when "Export"
        @ret = Nis.Export
      when "Packages"
        @ret = Nis.AutoPackages
      when "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Nis.WriteOnly
        Progress.set(@progress_orig)
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      # Finish
      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("NIS client autoinit client finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
      # EOF
    end
  end
end

Yast::NisAutoClient.new.main
