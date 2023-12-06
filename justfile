default: gen lint

gen:
    flutter pub get
    flutter_rust_bridge_codegen
    dart run build_runner build

lint:
    cd native && cargo fmt
    dart format .

clean:
    flutter clean
    cd native && cargo clean

serve *args='':
    dart run flutter_rust_bridge:serve {{args}}

# vim:expandtab:sw=4:ts=4
