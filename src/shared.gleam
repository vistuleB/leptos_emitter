import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import vxml_parser.{type VXML, V}

fn split_children_of_node_recursive(
  children: List(VXML),
  previous: String,
  i: Int,
) -> Dict(String, VXML) {
  case children {
    [] -> dict.new()
    [first, ..rest] -> {
      let assert V(b, tag, a, c) = first
      let counter = case tag == previous {
        True -> i + 1
        False -> 1
      }
      dict.insert(
        split_children_of_node_recursive(rest, tag, counter),
        string.lowercase(tag) <> string.inspect(counter),
        V(b, tag <> string.inspect(counter), a, c),
      )
    }
  }
}

/// Splits chapters and bootcamps into dict of (chapter1, vxml) ...
pub fn split_children_of_node(node: VXML) -> Dict(String, VXML) {
  let assert V(_, _, _, children) = node
  split_children_of_node_recursive(children, "", 1)
}

pub fn filter_counter_attributes(b_a: vxml_parser.BlamedAttribute) {
  !list.contains(["counter", "roman_counter", "is_self_closed"], b_a.key)
}
