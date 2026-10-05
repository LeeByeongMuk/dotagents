def exact_keys($names):
  (keys | sort) == ($names | sort);

type == "array" and
length > 0 and
([.[].id] | unique | length) == length and
all(.[];
  type == "object" and
  exact_keys(["id", "context", "request", "expected"]) and
  (.id | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
  (.context | type == "string" and test("\\S")) and
  (.request | type == "string" and test("\\S")) and
  (.expected |
    type == "object" and
    exact_keys([
      "route",
      "implementation_authorized",
      "file_changes_authorized",
      "authority_actions",
      "min_questions",
      "max_questions",
      "max_subagents",
      "min_acceptance_criteria",
      "min_deterministic_checks"
    ]) and
    (.route | IN("direct", "plan", "lean")) and
    (.implementation_authorized | type == "boolean") and
    (.file_changes_authorized | type == "boolean") and
    (.authority_actions | type == "array" and length > 0 and (unique | length) == length and all(.[]; IN("none", "reuse", "create", "link"))) and
    all(.["min_questions", "max_questions", "max_subagents", "min_acceptance_criteria", "min_deterministic_checks"];
      type == "number" and . >= 0 and floor == .)
    and .min_questions <= .max_questions
  )
)
