from pathlib import Path
import argparse
import sys


def get_converter_class():
    root = Path(__file__).resolve().parent
    assembler_dir = root / "riscv_assembler" / "riscv_assembler"
    sys.path.insert(0, str(assembler_dir))
    from convert import AssemblyConverter

    return AssemblyConverter


def main():
    parser = argparse.ArgumentParser(description="Assemble a RISC-V .s file into program.txt hex words.")
    parser.add_argument(
        "source",
        nargs="?",
        default="programs/addi_once.s",
        help="Path to input assembly file (.s), relative to p4/",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="program.txt",
        help="Output program file, one 32-bit hex word per line",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    source_path = (root / args.source).resolve()
    output_path = (root / args.output).resolve()

    AssemblyConverter = get_converter_class()
    converter = AssemblyConverter(output_mode="a", nibble_mode=False, hex_mode=True)
    machine_words = converter(str(source_path))

    with output_path.open("w", encoding="ascii") as f:
        for word in machine_words:
            f.write(word.replace("0x", "").upper() + "\n")

    print(f"Wrote {len(machine_words)} instructions to {output_path}")


if __name__ == "__main__":
    main()
