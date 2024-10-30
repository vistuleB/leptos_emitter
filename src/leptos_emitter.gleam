import shellout
import simplifile
import gleam/list
import gleam/io
import gleam/string
import vxml_parser.{
  type VXML, T, V,  parse_file
}

const ins = string.inspect
const spaces = "    "

fn map_with_special_last(
  z: List(a),
  fn1: fn(a) -> b,
  fn2: fn(a) -> b,
) -> List(b) {
  case z {
    [] -> []
    [last] -> [fn2(last)]
    [first, ..rest] ->
      fn1(first) |> list.prepend(map_with_special_last(rest, fn1, fn2), _)
  }
}

fn map_with_special_first_last(
  z: List(a),
  fn_first: fn(a) -> b,
  fn_middle: fn(a) -> b,
  fn_last: fn(a) -> b,
  fn_first_and_last: fn(a) -> b,
) -> List(b) {
  case z {
    [] -> []
    [first, ..rest] -> {
      case rest {
        [] -> list.prepend([], fn_first_and_last(first))

        [_, ..] -> {
          fn_first(first)
          |> list.prepend(map_with_special_last(rest, fn_middle, fn_last), _)
        }
      }
    }
  }
}

fn debug_print_vxml_as_leptos_xml_internal(
  pre_blame: String,
  indentation: String,
  t: VXML,
  output: String
) {
  case t {
    T(_, blamed_contents) -> {
      let map = map_with_special_first_last(
        blamed_contents,
        fn(first) {
          {
            "r#\""
            <> first.content
          }
        },
        fn(middle) {
          {
            middle.content
          }
        },
        fn(last) {
          {
            last.content
            <> "\"#"
          }
        },
        fn(first_and_last) {
          {
            "r#\""
            <> first_and_last.content
            <> "\"#"
          }
        },
      )
      output <> string.join(map, "")
    }

    V(_, tag, blamed_attributes, children) -> {
      case list.is_empty(children) {
        False -> {
          
          let attrs = list.map(blamed_attributes, fn(t) {
            { " " <> t.key <> "=\"" <> t.value <> "\"" }
          })
          output
          <> "<"
          <> tag
          <> string.join(attrs, "")
          <> ">"
          <> debug_print_vxmls_as_leptos_xml_internal(
            pre_blame,
            indentation <> spaces,
            children,
            output
          )
          <> "</"
          <> tag
          <> ">"
        }

        True -> {
          let attrs = list.map(blamed_attributes, fn(t) {
            { " " <> t.key <> "=\"" <> t.value <> "\"" }
          })

          output
            <> "<"
            <> tag
            <> string.join(attrs, "")
            <> "></" <> tag <> ">"

        }
      }
    }
  }
}

fn debug_print_vxmls_as_leptos_xml_internal(
  pre_blame: String,
  indentation: String,
  vxmls: List(VXML),
  output: String
) {
  case vxmls {
    [] -> output
    [first, ..rest] -> {
      let output = debug_print_vxml_as_leptos_xml_internal(pre_blame, indentation, first, output)
      debug_print_vxmls_as_leptos_xml_internal(pre_blame, indentation, rest, output)
    }
  }
}

pub fn leptos_emitter(pre_blame: String, vxmls: List(VXML)) {
  let output: String = ""
  debug_print_vxmls_as_leptos_xml_internal(pre_blame, "", vxmls, output)
}

fn update_for_format(output: String) -> String {
  "view! {"
  <> output
  <> "}"
}

fn write_file(output: String) {
  let path = "test/output.rs"
  let assert Ok(Nil) = simplifile.write(path, update_for_format(output))
  io.println("Output written to " <> path)

  case shellout.command("leptosfmt", with: [path], in: ".", opt: []) {
    Ok(res) -> io.println("Output formatted with leptosfmt: " <> res)
    Error(#(_, error)) -> io.println("Error formating output : " <> error)
  }
}

pub fn main() {
  let path = "test/sample.vxml"

  case parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      io.println("\nsuccessfully parsed; pure string emitter:\n")
      io.println("\nmakeshit leptos-debug-emitter:\n")
      let _ = write_file(leptos_emitter("(_no_message_)", vxmls))
    }
    Error(e) -> io.println("there was an error: " <> ins(e))
  }
}
