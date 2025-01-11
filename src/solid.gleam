import blamedlines.{
  type Blame, type BlamedLine, BlamedLine, blamed_lines_to_string,
  blamed_lines_to_table_vanilla_bob_and_jane_sue,
}
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shared.{filter_counter_attributes, split_children_of_node}
import simplifile
import vxml_parser.{type BlamedAttribute, type VXML, T, V}

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

fn is_self_closed(attributes: List(BlamedAttribute)) {
  attributes
  |> list.map(fn(t) { t.key })
  |> list.contains("is_self_closed")
}

fn tag_open_blamed_line(
  blame: Blame,
  tag: String,
  indent: Int,
  closing: String,
  attributes: List(BlamedAttribute),
) {
  case list.is_empty(attributes) {
    True ->
      BlamedLine(blame: blame, indent: indent, suffix: "<" <> tag <> closing)
    False -> BlamedLine(blame: blame, indent: indent, suffix: "<" <> tag)
  }
}

fn attributes_to_blamed_lines(
  attributes: List(BlamedAttribute),
  indent: Int,
  inlude_at_last: String,
) -> List(BlamedLine) {
  case
    attributes
    |> list.filter(filter_counter_attributes)
    |> list.map(fn(t) {
      BlamedLine(
        blame: t.blame,
        indent: indent + 2,
        suffix: to_solid_attribute(t.key, t.value),
      )
    })
    |> list.reverse()
  {
    [] -> []
    [last, ..rest] -> {
      rest
      |> list.reverse()
      |> list.append([BlamedLine(..last, suffix: last.suffix <> inlude_at_last)])
    }
  }
}

pub fn vxml_to_jsx_blamed_lines(t: VXML, indent: Int) -> List(BlamedLine) {
  case t {
    T(_, blamed_contents) -> {
      blamed_contents
      |> list.map(fn(t) {
        BlamedLine(
          blame: t.blame,
          indent: indent,
          suffix: jsx_string_processor(t.content),
        )
      })
    }

    V(blame, tag, blamed_attributes, children) -> {
      case list.is_empty(children) {
        False -> {
          let tag_close_line =
            BlamedLine(blame: blame, indent: indent, suffix: "</" <> tag <> ">")

          list.flatten([
            [tag_open_blamed_line(blame, tag, indent, ">", blamed_attributes)],
            attributes_to_blamed_lines(blamed_attributes, indent + 2, ">"),
            vxmls_to_jsx_blamed_lines(children, indent + 2),
            [tag_close_line],
          ])
        }

        True -> {
          case is_self_closed(blamed_attributes) {
            True -> {
              list.flatten([
                [
                  tag_open_blamed_line(
                    blame,
                    tag,
                    indent,
                    "/>",
                    blamed_attributes,
                  ),
                ],
                attributes_to_blamed_lines(blamed_attributes, indent + 2, "/>"),
              ])
            }

            False -> {
              let tag_close_line =
                BlamedLine(
                  blame: blame,
                  indent: indent,
                  suffix: "</" <> tag <> ">",
                )

              list.flatten([
                [
                  tag_open_blamed_line(
                    blame,
                    tag,
                    indent,
                    ">",
                    blamed_attributes,
                  ),
                ],
                attributes_to_blamed_lines(blamed_attributes, indent + 2, ">"),
                [tag_close_line],
              ])
            }
          }
        }
      }
    }
  }
}

pub fn vxmls_to_jsx_blamed_lines(vxmls: List(VXML), indent: Int) -> List(BlamedLine) {
  vxmls
  |> list.map(vxml_to_jsx_blamed_lines(_, indent))
  |> list.flatten
}

pub fn vxml_to_jsx(vxml: VXML) -> String {
  vxml_to_jsx_blamed_lines(vxml, 0)
  |> blamed_lines_to_string
}

pub fn debug_vxml_to_jsx(banner: String, vxml: VXML) -> String {
  vxml
  |> vxml_parser.debug_annotate_blames
  |> vxml_to_jsx_blamed_lines(_, 0)
  |> blamedlines.blamed_lines_to_table_vanilla_bob_and_jane_sue(banner, _)
}

fn add_solid_boilerplate(output: String) -> String {
  "const Article = () => {
  return <>\n" <> output <> "</>
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
      path <> "/" <> split_key <> ".tsx",
    )
  })
}
