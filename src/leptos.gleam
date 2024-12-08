import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import shared.{split_children_of_node}
import shellout
import simplifile
import vxml_parser.{type VXML, T, V}

type SkipNext =
  Bool

fn to_leptos_attribute(key, value) {
  let value = string.trim(value)
  case
    float.parse(value),
    int.parse(value),
    value == "false" || value == "true",
    string.starts_with(value, "vec![")
  {
    Error(_), Error(_), False, False -> {
      { " " <> key <> "=\"" <> value <> "\"" }
    }
    _, _, _, _ -> {
      { " " <> key <> "=" <> value <> "" }
    }
  }
}

fn filter_counter_attributes(b_a: vxml_parser.BlamedAttribute) {
  !list.contains(["counter", "roman_counter"], b_a.key)
}

fn debug_print_vxml_as_leptos_xml_internal(
  t: VXML,
  next: option.Option(VXML),
  output: String,
) -> #(String, SkipNext) {
  case t {
    T(_, blamed_contents) -> {
      let contents = list.map(blamed_contents, fn(t) { t.content })
      let #(contents, skip_next) = case next {
        option.Some(T(_, blamed_contents)) -> {
          #(
            contents
              |> list.append(list.map(blamed_contents, fn(t) { t.content })),
            True,
          )
        }
        _ -> #(contents, False)
      }

      #(output <> "r#\"" <> string.join(contents, "\n") <> "\"#", skip_next)
    }

    V(_, tag, blamed_attributes, children) -> {
      case list.is_empty(children) {
        False -> {
          let attrs =
            blamed_attributes
            |> list.filter(filter_counter_attributes)
            |> list.map(fn(t) { to_leptos_attribute(t.key, t.value) })
          #(
            output
              <> "<"
              <> tag
              <> string.join(attrs, "")
              <> ">"
              <> debug_print_vxmls_as_leptos_xml_internal(children, "")
              <> "</"
              <> tag
              <> ">",
            False,
          )
        }

        True -> {
          let attrs =
            blamed_attributes
            |> list.filter(filter_counter_attributes)
            |> list.map(fn(t) { to_leptos_attribute(t.key, t.value) })

          #(
            output
              <> "<"
              <> tag
              <> string.join(attrs, "")
              <> "></"
              <> tag
              <> ">",
            False,
          )
        }
      }
    }
  }
}

fn debug_print_vxmls_as_leptos_xml_internal(vxmls: List(VXML), output: String) {
  case vxmls {
    [] -> output
    [last] -> {
      let #(output, _) =
        debug_print_vxml_as_leptos_xml_internal(last, option.None, output)
      output
    }
    [first, next, ..rest] -> {
      let #(output, skip_next) =
        debug_print_vxml_as_leptos_xml_internal(
          first,
          option.Some(next),
          output,
        )
      case skip_next {
        True -> {
          debug_print_vxmls_as_leptos_xml_internal(rest, output)
        }
        False -> {
          debug_print_vxmls_as_leptos_xml_internal(
            list.append([next], rest),
            output,
          )
        }
      }
    }
  }
}

pub fn leptos_emitter(vxmls: List(VXML)) {
  debug_print_vxmls_as_leptos_xml_internal(vxmls, "")
}

fn add_boilerplate(output: String) -> String {
  "view! {" <> output <> "}"
}

pub fn write_file_leptos(output: String, path: String) {
  let assert Ok(Nil) = simplifile.write(path, add_boilerplate(output))

  case shellout.command("leptosfmt", with: [path], in: ".", opt: []) {
    Ok(_) -> io.println("Output formatted with leptosfmt")
    Error(#(_, error)) -> io.println("Error formating output : " <> error)
  }
}

pub fn write_splitted_leptos(vxml: VXML, path: String) {
  split_children_of_node(vxml)
  |> dict.each(fn(split_key, node) {
    write_file_leptos(leptos_emitter([node]), path <> "/" <> split_key <> ".rs")
  })
}
