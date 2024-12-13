import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import shared.{filter_counter_attributes, split_children_of_node}
import simplifile
import vxml_parser.{type VXML, T, V}

type SkipNext =
  Bool

fn to_solid_attribute(key, value) {
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
    _, _, _, True -> {
      { " " <> key <> "={" <> string.drop_left(value, 4) <> "}" }
    }
    _, _, _, _ -> {
      { " " <> key <> "={" <> value <> "}" }
    }
  }
}

fn debug_print_vxml_as_jsx_internal(
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

      #(output <> "{`" <> string.join(contents, "\n") <> "`}", skip_next)
    }

    V(_, tag, blamed_attributes, children) -> {
      case list.is_empty(children) {
        False -> {
          let attrs =
            blamed_attributes
            |> list.filter(filter_counter_attributes)
            |> list.map(fn(t) { to_solid_attribute(t.key, t.value) })

          let is_self_closed =
            blamed_attributes
            |> list.map(fn(t) { t.key })
            |> list.contains("is_self_closed")

          case is_self_closed {
            True -> #(
              output <> "<" <> tag <> string.join(attrs, "") <> " />",
              False,
            )
            _ -> #(
              output
                <> "<"
                <> tag
                <> string.join(attrs, "")
                <> ">"
                <> debug_print_vxmls_as_jsx_internal(children, "")
                <> "</"
                <> tag
                <> ">",
              False,
            )
          }
        }

        True -> {
          let attrs =
            blamed_attributes
            |> list.filter(filter_counter_attributes)
            |> list.map(fn(t) { to_solid_attribute(t.key, t.value) })

          let is_self_closed =
            blamed_attributes
            |> list.map(fn(t) { t.key })
            |> list.contains("is_self_closed")

          case is_self_closed {
            True -> #(
              output <> "<" <> tag <> string.join(attrs, "") <> " />",
              False,
            )
            False -> #(
              output
                <> "<"
                <> tag
                <> string.join(attrs, "")
                <> ">"
                <> debug_print_vxmls_as_jsx_internal(children, "")
                <> "</"
                <> tag
                <> ">",
              False,
            )
          }
        }
      }
    }
  }
}

fn debug_print_vxmls_as_jsx_internal(vxmls: List(VXML), output: String) {
  case vxmls {
    [] -> output
    [last] -> {
      let #(output, _) =
        debug_print_vxml_as_jsx_internal(last, option.None, output)
      output
    }
    [first, next, ..rest] -> {
      let #(output, skip_next) =
        debug_print_vxml_as_jsx_internal(first, option.Some(next), output)
      case skip_next {
        True -> {
          debug_print_vxmls_as_jsx_internal(rest, output)
        }
        False -> {
          debug_print_vxmls_as_jsx_internal(list.append([next], rest), output)
        }
      }
    }
  }
}

pub fn solid_emitter(vxmls: List(VXML)) {
  debug_print_vxmls_as_jsx_internal(vxmls, "")
}

fn add_boilerplate(output: String) -> String {
  "const Article = () => {
    return <> " <> output <> " </>
  }
  export default Article
  "
}

pub fn write_file_solid(output: String, path: String) {
  let assert Ok(Nil) = simplifile.write(path, add_boilerplate(output))
  // case shellout.command("leptosfmt", with: [path], in: ".", opt: []) {
  //   Ok(_) -> io.println("Output formatted with leptosfmt")
  //   Error(#(_, error)) -> io.println("Error formating output : " <> error)
  // }
  Nil
}

pub fn write_splitted_jsx(vxml: VXML, path: String) {
  split_children_of_node(vxml)
  |> dict.each(fn(split_key, node) {
    write_file_solid(solid_emitter([node]), path <> "/" <> split_key <> ".tsx")
  })
}
