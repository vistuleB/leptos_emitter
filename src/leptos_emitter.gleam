import gleam/float
import gleam/int
import gleam/option
import shellout
import simplifile
import gleam/list
import gleam/io
import gleam/string
import vxml_parser.{
  type VXML, T, V,  parse_file
}

const ins = string.inspect

type SkipNext = Bool

fn to_leptos_attribute(key, value) {
  case float.parse(value), int.parse(value) {
    Error(_), Error(_) -> {
        { " " <> key <> "=\"" <> value <> "\"" }
    }
    _, _ -> {
        { " " <> key <> "=" <> value <> "" }
    }
  }
}

fn debug_print_vxml_as_leptos_xml_internal(
  t: VXML,
  next: option.Option(VXML),
  output: String
) -> #(String, SkipNext) {
  
  case t {
    T(_, blamed_contents) -> {
      let contents = list.map(blamed_contents, fn(t) {
            t.content
      })
      let #(contents, skip_next) = case next {
        option.Some(T(_, blamed_contents)) -> {
          #(contents |> list.append(list.map(blamed_contents, fn(t) {
            t.content
          })), True)
        }
        _ -> #(contents, False)
      }

      #(output <> "r#\"" <> string.join(contents, " ") <> "\"#", skip_next)
    }

    V(_, tag, blamed_attributes, children) -> {
      case list.is_empty(children) {
        False -> {
          
          let attrs = list.map(blamed_attributes, fn(t) {
            to_leptos_attribute(t.key, t.value)
          })
          #(output
          <> "<"
          <> tag
          <> string.join(attrs, "")
          <> ">"
          <> debug_print_vxmls_as_leptos_xml_internal(
            children,
            output
          )
          <> "</"
          <> tag
          <> ">", False)
        }

        True -> {
          let attrs = list.map(blamed_attributes, fn(t) {
            to_leptos_attribute(t.key, t.value)
          })

          #(output
            <> "<"
            <> tag
            <> string.join(attrs, "")
            <> "></" <> tag <> ">", False)

        }
      }
    }
  }
}

fn debug_print_vxmls_as_leptos_xml_internal(
  vxmls: List(VXML),
  output: String
) {
  case vxmls {
    [] -> output
    [last] -> {
      let #(output, _) = debug_print_vxml_as_leptos_xml_internal(last, option.None, output)
      output
    }
    [first, next, ..rest] -> {
      let #(output, skip_next) = debug_print_vxml_as_leptos_xml_internal(first, option.Some(next), output)
      case skip_next {
        True -> {
          debug_print_vxmls_as_leptos_xml_internal(rest, output)
        }
        False -> {
          debug_print_vxmls_as_leptos_xml_internal(list.append([next], rest), output)
        }
      }
      
    }
  }
}

pub fn leptos_emitter(vxmls: List(VXML)) {
  let output: String = ""

  debug_print_vxmls_as_leptos_xml_internal(vxmls, output)
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
      let _ = write_file(leptos_emitter(vxmls))
    }
    Error(e) -> io.println("there was an error: " <> ins(e))
  }
}
