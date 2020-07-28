require_relative "test_helper"

Yast.import "Nis"

describe Yast::Nis do
  subject { Yast::Nis }

  before do
    allow(Yast::SCR).to receive(:Read)
    allow(Yast::SCR).to receive(:Write).and_return(true)
    allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0, "stdout" => "")
    allow(Yast::Service).to receive(:Enabled).and_return(false)
    allow(Yast::Service).to receive(:active?).and_return(false)
    allow(Yast::Service).to receive(:Start)
    allow(Yast::Service).to receive(:Restart)
    allow(Yast::Service).to receive(:Stop)
    allow(Yast::Service).to receive(:Enable)
    allow(Yast::Service).to receive(:Disable)
    allow(Yast::Service).to receive(:Status).and_return(0)
    allow(Y2Firewall::Firewalld.instance).to receive(:read)
    allow(Yast::Autologin).to receive(:Read)
    allow(Yast::Nsswitch).to receive(:Write).and_return(true)
    allow(Yast::Nsswitch).to receive(:ReadDb).and_return([])
    allow(Yast::Package).to receive(:Installed).and_return(true)

    subject.main
  end

  describe ".Read" do
    it "reads ypbind service status" do
      allow(Yast::Service).to receive(:Enabled).and_return(true)

      subject.Read
      expect(subject.start).to eq true
    end

    it "reads domain from ypdomainname output" do
      expect(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash_output"), "/usr/bin/ypdomainname")
        .and_return("exit" => 0, "stdout" => "pepa.suse.cz")

      subject.Read
      expect(subject.GetDomain).to eq "pepa.suse.cz"
    end

    # Is it still valid way with wicked?
    it "reads if dhcpcd is running" do
      expect(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash"), /dhcpcd/)
        .and_return(0)

      subject.Read
      expect(subject.dhcpcd_running).to eq true
    end

    it "reads local_only flag" do
      expect(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.ypbind.YPBIND_LOCAL_ONLY")).and_return("yes")

      subject.Read
      expect(subject.local_only).to eq true
    end

    it "reads global_broadcast flag" do
      expect(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.ypbind.YPBIND_BROADCAST")).and_return("yes")

      subject.Read
      expect(subject.global_broadcast).to eq true
    end

    it "reads broken_server flag" do
      expect(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.ypbind.YPBIND_BROKEN_SERVER")).and_return("yes")

      subject.Read
      expect(subject.broken_server).to eq true
    end

    it "reads options" do
      expect(Yast::SCR).to receive(:Read)
        .with(path(".sysconfig.ypbind.YPBIND_OPTIONS")).and_return("yohoho")

      subject.Read
      expect(subject.options).to eq "yohoho"
    end

    context "if options cannot be read" do
      before do
        allow(Yast::SCR).to receive(:Read)
          .with(path(".sysconfig.ypbind.YPBIND_OPTIONS")).and_return(nil)
      end

      it "sets the option to an empty string" do
        subject.Read
        expect(subject.options).to eq ""
      end
    end

    it "reads if users is defined in ldap" do
      expect(Yast::Nsswitch).to receive(:ReadDb).with("passwd").and_return(["ldap"])

      subject.Read
      expect(subject.UsersByLdap).to eq true
    end

    it "reads autologin settings" do
      expect(Yast::Autologin).to receive(:Read)

      subject.Read
    end

    it "reads firewall settings" do
      expect(Y2Firewall::Firewalld.instance).to receive(:read)

      subject.Read
    end
  end

  describe "#Write" do
    # TODO: weak test and also some behavior missing
    it "calls WriteOnly" do
      expect(subject).to receive(:WriteOnly).and_return(true)

      subject.Write
    end

    it "stops ypbind" do
      expect(Yast::Service).to receive(:Stop)

      subject.Write
    end

    context "start flag is set" do
      before do
        subject.start = true
      end

      it "starts rpcbind if not already running" do
        allow(Yast::Service).to receive(:Status).with("rpcbind").and_return(1)
        expect(Yast::Service).to receive(:Start).with("rpcbind")

        subject.Write
      end

      it "starts ypbind" do
        expect(Yast::Service).to receive(:Start).with("ypbind")

        subject.Write
      end
    end

    it "reloads firewall" do
      expect(Y2Firewall::Firewalld.instance).to receive(:reload)

      subject.Write
    end
  end

  describe "#Export" do
    let(:ypbind_installed) { true }
    let(:config_mode) { false }

    before do
      allow(Yast::Package).to receive(:Installed).with("ypbind").and_return(ypbind_installed)
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
      subject.Import(
        "start_nis"   => true,
        "nis_servers" => ["nis.example.net"]
      )
    end

    it "returns module settings" do
      expect(subject.Export).to include(
        "start_nis"   => subject.start,
        "nis_servers" => subject.servers
      )
    end

    context "when the ypbind package is not installed" do
      let(:ypbind_installed) { false }

      context "during config mode" do
        let(:config_mode) { true }

        it "returns the module settings" do
          expect(subject.Export).to_not be_empty
        end
      end

      context "during not config mode" do
        let(:config_mode) { false }

        it "returns an empty hash" do
          expect(subject.Export).to eq({})
        end
      end
    end
  end
end
