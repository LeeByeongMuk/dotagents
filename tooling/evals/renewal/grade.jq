def nonempty: type == "string" and test("\\S");
def matches($expected): . as $actual | all($expected | to_entries[]; $actual[.key] == .value);

# Validate all schema fields, including those not scored for a given scenario.
. as $record
| $schema[0].properties.decisions.items as $item_schema
| if ($record.label != "baseline" and $record.label != "candidate") then error("unknown label") else . end
| if ($record.requested_model != "gpt-6.1-sol" or $record.requested_effort != "high") then error("unexpected model or effort") else . end
| if ($record.decision | keys) != ["decisions"] then error("invalid decision envelope") else . end
| $record.decision.decisions as $decisions
| if ($decisions | type) != "array" or ($decisions | length) != ($cases[0] | length) then error("incomplete batch") else . end
| if ($decisions | map(.id) | sort) != ($cases[0] | map(.id) | sort) then error("unknown, missing or duplicate case") else . end
| if all($decisions[];
    . as $d
    | (keys | sort) == ($item_schema.required | sort)
      and all($item_schema.properties | to_entries[];
        . as $p | ($d[$p.key] | type) == $p.value.type
        and (if $p.value.enum then ($p.value.enum | index($d[$p.key])) != null else true end))
      and (.rationale | nonempty)
      and (.next_steps | length > 0 and all(.[]; nonempty))) | not
  then error("invalid decision fields") else . end
| [ $cases[0][] as $case
    | ($decisions[] | select(.id == $case.id)) as $d
    | {id: $case.id,
       common: (if ($d | matches($case.common_expected)) then "PASS" else "FAIL" end),
       candidate_capability: (if $record.label == "baseline" then "NOT_SCORED"
         elif ($d | matches($case.candidate_expected)) then "PASS" else "FAIL" end),
       interface: $d.recommended_interface,
       first_use_protection: $d.first_use_protection,
       batch_failure_effect: $d.batch_failure_effect}
  ] as $rows
| {label: $record.label, results: $rows,
   common_passed: ([$rows[] | select(.common == "PASS")] | length),
   candidate_capability_passed: (if $record.label == "candidate" then ([$rows[] | select(.candidate_capability == "PASS")] | length) else null end),
   passed: all($rows[]; .common == "PASS" and .candidate_capability != "FAIL")}
