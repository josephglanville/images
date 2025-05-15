load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _sum_impl(ctx):
    http_archive(
        name = "sum_arm64",
        urls = ["https://www.supermicro.com/Bios/sw_download/692/sum_2.14.0_Linux_arm64_20240215.tar.gz"],
        integrity = "sha256-MPtVQQy7DWS62MYdVPQKOXa75Hx0012523O8XAvlsJE=",
        add_prefix = "opt/sum",
        strip_prefix = "sum_2.14.0_Linux_arm64",
        build_file_content = """
filegroup(
    name = "sum_files",
    srcs = glob(["opt/sum/**/*"]),
    visibility = ["//visibility:public"],
)
""",
    )

    http_archive(
        name = "sum_x86_64",
        urls = ["https://www.supermicro.com/Bios/sw_download/698/sum_2.14.0_Linux_x86_64_20240215.tar.gz"],
        integrity = "sha256-ec8mIDSTu2pbZPxQjZaWFR+J4It5EgpYLTN71armwKE=",
        add_prefix = "opt/sum",
        strip_prefix = "sum_2.14.0_Linux_x86_64",
        build_file_content = """
filegroup(
    name = "sum_files",
    srcs = glob(["opt/sum/**/*"]),
    visibility = ["//visibility:public"],
)
""",
    )

sum = module_extension(
    implementation = _sum_impl,
    tag_classes = {},
)