require 'csv'

all_cancelled = Policy.collection.raw_aggregate([
                                                    {
                                                        "$unwind" => "$enrollees"
                                                    },
                                                    {"$project" => {"is_cancelled" => {"$eq" => ["$enrollees.coverage_start", "$enrollees.coverage_end"]}, "_id" => 1, "enrollees.rel_code" => 1}},
                                                    {"$match" => {"is_cancelled" => true, "enrollees.rel_code" => "self"}}
                                                ])

puts "Cancelled Policies: #{all_cancelled.count}"

cancelled_ids = all_cancelled.map do |ac|
  ac["_id"]
end

all_m_ids = Person.collection.raw_aggregate([
                                                {
                                                    "$unwind" => "$members"
                                                },
                                                {"$project" => {"is_authority" => {"$eq" => ["$members.hbx_member_id", "$authority_member_id"]}, "members.hbx_member_id" => 1}},
                                                {"$match" => {"is_authority" => true}}
                                            ])

all_authority_ids = all_m_ids.map do |mid|
  mid["members"]["hbx_member_id"]
end

active_policies = Policy.where(:id => {"$nin" => cancelled_ids}, "enrollees.m_id" => {"$in" => all_authority_ids})

m_cache_ids = Policy.collection.raw_aggregate([
                                                  {
                                                      "$unwind" => "$enrollees"
                                                  },
                                                  {"$project" => {"is_cancelled" => {"$eq" => ["$enrollees.coverage_start", "$enrollees.coverage_end"]}, "enrollees.m_id" => 1, "enrollees.rel_code" => 1}},
                                                  {"$match" => {"is_cancelled" => true, "enrollees.rel_code" => "self"}}
                                              ])

active_policy_count = active_policies.count

m_ids = []
active_policies.each do |m_pol|
  if !m_pol.subscriber.nil?
    m_ids = m_ids + m_pol.enrollees.map(&:m_id)
  end
end

m_ids.uniq!


puts "Precaching members"
member_cache = Caches::MemberIdPerson.new(m_ids)
puts "Members precached."

plan_hash = Plan.all.inject({}) do |acc, p|
  acc[p.id] = p
  acc
end

puts "Active Policies: #{active_policy_count}"

counter = 0

m_cache = Hash.new do |h, k|
  h[k] = Person.where({
                          "members.hbx_member_id" => k
                      }).first
end

pb = ProgressBar.create(
    :title => "Dumping policies",
    :total => active_policy_count,
    :format => "%t %a %e |%B| %P%%"
)

def csv_date_format(d)
  return nil if d.blank?
  d.strftime("%Y-%m-%d")
end

CSV.open("active_policies#{Time.now.to_s.gsub(' ', '')}.csv", "wb") do |csv|
  csv << [
      "policy_id",
      "enrollment_group_id",
      "market",
      "policy_start",
      "policy_end",
      "hios_id",
      "plan_year",
      "plan_name",
      "ehb_percentage",
      "totalcost",
      "applied_aptc",
      "employer_contribution",
      "responsible_amount",
      "coverage_startdate",
      "coverage_enddate",
      "subscriber_hbx_id",
      "subscriber_firstname",
      "subscriber_lastname",
      "subscriber_ssn",
      "subscriber_premium_amount",
      "subscriber_dob",
      "subscriber_gender",
      "metal_level",
      "relationship"
  ]
  active_policies.each do |ap|

    begin
      if ap.coverage_period_end.present? && ap.coverage_period_end.past?
        next
      end
    rescue Exception => e

    end

    if !ap.subscriber.nil?
      subscriber = ap.subscriber
      if !subscriber.canceled?
        ap.enrollees.each do |enrollee|
          sub_person = member_cache.lookup(enrollee.m_id)
          plan = plan_hash[ap.plan_id]
          if !sub_person.authority_member.nil? && !enrollee.canceled?
            csv << [
                ap.id,
                ap.enrollment_group_id,
                ap.market,
                csv_date_format(ap.policy_start),
                (csv_date_format(ap.coverage_period_end) rescue ""),
                plan.hios_plan_id,
                plan.year.to_s,
                plan.name,
                plan.ehb,
                ap.pre_amt_tot,
                ap.applied_aptc,
                ap.tot_emp_res_amt,
                ap.tot_res_amt,
                csv_date_format(enrollee.coverage_start),
                (csv_date_format(enrollee.coverage_end) rescue ""),
                sub_person.authority_member_id,
                sub_person.name_first,
                sub_person.name_last,
                sub_person.authority_member.ssn,
                enrollee.pre_amt,
                csv_date_format(sub_person.authority_member.dob),
                sub_person.authority_member.gender,
                plan.metal_level,
                enrollee.rel_code
            ]
          end
        end
      end
    end
    pb.increment
  end
end
