import gleam/dict
import gleam/result
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import shared.{filter_counter_attributes, split_children_of_node}
import simplifile
import vxml_parser.{type VXML, T, V}

fn to_solid_attribute(key, value) -> String {
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
      { " " <> key <> "={" <> string.drop_start(value, 4) <> "}" }
    }
    _, _, _, _ -> {
      { " " <> key <> "={" <> value <> "}" }
    }
  }
}

fn jsx_string_processor(content: String) -> String {
  content
  |> string.replace("{", "&#123;")
  |> string.replace("}", "&#125;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn vxmls_to_jsx(
  vxmls: List(VXML)
) -> String {
  vxmls
  |> list.map(vxml_to_jsx)
  |> string.join("")
}

pub fn vxml_to_jsx(
  t: VXML
) -> String {
  case t {
    T(_, blamed_contents) -> {
      blamed_contents
      |> list.map(fn(t) {jsx_string_processor(t.content)})
      |> string.join("\n{\" \"}")
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
            True -> "<" <> tag <> string.join(attrs, "") <> " />"
            _ -> {
              "<"
              <> tag
              <> string.join(attrs, "")
              <> ">"
              <> vxmls_to_jsx(children)
              <> "</"
              <> tag
              <> ">"
            }
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
            True -> {
              "<" <> tag <> string.join(attrs, "") <> " />"
            }

            False -> {
                "<"
                <> tag
                <> string.join(attrs, "")
                <> ">"
                <> vxmls_to_jsx(children)
                <> "</"
                <> tag
                <> ">"
            }
          }
        }
      }
    }
  }
}

fn add_solid_boilerplate(output: String) -> String {
  "const Article = () => {
  return <>" <> output <> "</>
}
export default Article
"
}

pub fn write_file_solid(output: String, path: String) -> Nil {
  output
  |> add_solid_boilerplate
  |> simplifile.write(path, _)
  |> result.unwrap(Nil)
}

pub fn write_splitted_jsx(vxml: VXML, path: String) -> Nil {
  split_children_of_node(vxml)
  |> dict.each(fn(split_key, node) {
    write_file_solid(
      vxml_to_jsx(node),
      path <> "/" <> split_key <> ".tsx"
    )
  })
}
