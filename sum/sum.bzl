load("@aspect_bazel_lib//lib:tar.bzl", "tar")

def sum_layer(name):
    """Creates a layer with the Supermicro Update Manager (SUM) binaries.

    Args:
        name: The name of the layer.
    """

    # Create a tar file with the SUM binaries for the appropriate architecture
    tar(
        name = name,
        srcs = select({
            "@platforms//cpu:arm64": ["@sum_arm64//:sum_files"],
            "@platforms//cpu:x86_64": ["@sum_x86_64//:sum_files"],
        }),
    )
