import gleam/io
import gleam/string
import vxml_parser.{debug_print_vxmls_as_leptos_xml, emit_vxmls, parse_file}

const ins = string.inspect

pub fn main() {
  let path = "../vxml_parser/test/sample.vxml"

  case parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      io.println("\nsuccessfully parsed; pure string emitter:\n")
      io.println(emit_vxmls(vxmls))
      io.println("\nmakeshit leptos-debug-emitter:\n")
      debug_print_vxmls_as_leptos_xml("(_no_message_)", vxmls)
    }
    Error(e) -> io.println("there was an error: " <> ins(e))
  }
}
