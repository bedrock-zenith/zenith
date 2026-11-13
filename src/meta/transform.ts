import protocol from "./__protocol__.json" with { type: "json" };
import { writeFile } from "node:fs/promises";

var enums = "";

for (const enum_data of protocol.enums) {
  enums += `
const ${enum_data.name.replaceAll(" ", "")} = enum(${enum_data.backing_integer}) {
    ${Object.entries(enum_data.enum)
      .map((_) => `@"${_[0]}" = ${_[1]},\n`)
      .join("")}
};
`;
}

await writeFile("./enums.zig", enums);
