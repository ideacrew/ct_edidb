namespace :ct_demo do
  desc "Load Demo Carrier Profiles"
  task :load_carriers => :environment do
    abcbs_carrier = Carrier.create!({
      hbx_carrier_id: "20014",
      name: "Anthem BlueCross BlueShield",
      abbrev: "ABCBS",
      carrier_profiles: [
        CarrierProfile.new({
          profile_name: "ABCBS_IVL",
          fein: "061475928"
        }),
        CarrierProfile.new({
          profile_name: "ABCBS_SHP",
          fein: "061475928"
        })
      ]
    })
    abcbs_tp = TradingPartner.create!({
      name: "Anthem BlueCross BlueShield",
      trading_profiles: [
        TradingProfile.new({
          profile_name: "ABCBS_IVL",
          profile_code: "061475928"
        }),
        TradingProfile.new({
          profile_name: "ABCBS_SHP",
          profile_code: "061475928"
        })
      ]
    })
    ccare_carrier = Carrier.create!({
      hbx_carrier_id: "20015",
      name: "ConnectiCare",
      abbrev: "CCARE",
      carrier_profiles: [
        CarrierProfile.new({
          profile_name: "CCARE_IVL",
          fein: "237442369"
        }),
        CarrierProfile.new({
          profile_name: "CCARE_SHP",
          fein: "237442369"
        })
      ]
    })
    ccare_tp = TradingPartner.create!({
      name: "ConnectiCare",
      trading_profiles: [
        TradingProfile.new({
          profile_name: "CCARE_IVL",
          profile_code: "237442369"
        }),
        TradingProfile.new({
          profile_name: "CCARE_SHP",
          profile_code: "237442369"
        })
      ]
    })
  end
end
