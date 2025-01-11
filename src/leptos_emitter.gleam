import gleam/io
import gleam/string
import leptos.{leptos_emitter, write_file_leptos, write_splitted_leptos}
import solid
import vxml_parser.{type VXML, parse_file}

pub fn write_splitted(vxml: VXML, path: String, emitter: String) {
  case emitter {
    "leptos" -> write_splitted_leptos(vxml, path)
    "solid" -> solid.write_splitted_jsx(vxml, path)
    _ -> Nil
  }
}

pub fn write_file(vxml: VXML, path: String, emitter: String) {
  case emitter {
    "leptos" -> write_file_leptos(leptos_emitter([vxml]), path)
    "solid" -> solid.write_file_solid(solid.vxml_to_jsx(vxml, 6), path)
    _ -> io.println_error("Emitter " <> emitter <> " is not supported")
  }
}

pub fn main() {
  let path = "test/sample.vxml"

  case parse_file(path, "sample", False) {
    Ok(vxmls) -> {
      let assert [vxml] = vxmls
      io.println("\nsuccessfully parsed; pure string emitter:\n")
      io.println("\nmakeshit leptos-debug-emitter:\n")
      io.println(solid.debug_vxml_to_jsx("(main)", vxml))
      io.println(solid.add_solid_boilerplate(solid.vxml_to_jsx(vxml, 6)))
    }
    Error(e) -> io.println("there was an error: " <> string.inspect(e))
  }
}
