load("@bazel_skylib//lib:paths.bzl", "paths")
load("@tf_modules//rules:module.bzl", _terraform_module="terraform_module")
load("@tf_modules//rules:provider.bzl", "terraform_provider")
load("@tf_modules//rules:terraform.bzl", "terraform_working_directory")

def terraform_module(
        name,
        module_path = "",
        tf_vars = {},
        srcs = [],
        srcs_flatten = [],
        module_deps = [],
        provider_binaries=[], 
        provider_versions={},
        terraform_executable = Label("@terraform_default//:terraform_executable"),
        absolute_module_source_paths = True,
        visibility = ["//visibility:public"],
        **kwargs):
    """Defines a new Terraform module.

    This macro combines the terraform_module and terraform_working_directory rules from @tf_modules//rules to define a combined, runnable Terraform module.
    For modules that will only be used as dependencies, it is recommende to use the terraform_module rule directly without using this macro.

    For backwards compatibility, the terraform_working_directory target created will have allow_provider_download set to True. 
    This means that providers may be downloaded if not included in the WORKSPACE. This may result in non-hermetic builds.
    
    Args:
      name: Module name. A target will be added with the suffix "_terraform" to run the Terraform binary.
      module_path: Path to the Terraform module directory relative to the module root. Defaults to empty.
      tf_vars: Map of Terraform variables to be passed into the module.
      srcs: List of files that define the module.
      srcs_flatten: List of files to flatten into the root of the module. This allows inclusion of files from other packages.
      module_deps: List of labels for other Terraform modules that this module depends on.
      provider_binaries: List of labels for Terraform provider binaries.
      provider_versions: Map of provider names to version constraints strings. Versions must be of the form <hostname>/<namespace>/<type>/<version>
      terraform_executable: Label of the Terraform executable target to use. Defaults to the workspace default version.
      absolute_module_source_paths: If True, source paths for dependencies will be absolute within the workspace. Otherwise, dependencies will be added as relative subdirectories.
      **kwargs: Additional keyword arguments passed through to the terraform_module rule.
    """

    if name == "terraform":
        fail("The name 'terraform' is reserved for the Terraform executable. Please use a different name for your module.")

    _terraform_module(
        name = name,
        module_path = module_path,
        srcs = srcs,
        srcs_flatten = srcs_flatten,
        module_deps = module_deps,
        absolute_module_source_paths = absolute_module_source_paths,
        visibility = visibility,
        **kwargs
    )

    providers = []
    for provider_binary in provider_binaries:
        v = provider_versions.get(provider_binary, "")
        version_segments = v.split("/")
        if len(version_segments) != 4:
            fail("Invalid provider version format (expected <hostname>/<namespace>/<type>/<version>): {}".format(v))
        
        target = ""
        segments = provider_binary.split(":")
        if len(segments) > 1:
            target = segments[1]
        else:
            target = provider_binary.split("/")[-1]

        provider_name = "{}_{}".format(name, target)
        terraform_provider(
            name = provider_name,
            binary = provider_binary,
            hostname = version_segments[0],
            namespace = version_segments[1],
            type = version_segments[2],
            version = version_segments[3],
        )
        providers.append(":" + provider_name)

    module_ref = ":{}".format(name)
    terraform_working_directory(
        name = "{}_terraform".format(name),
        module = module_ref,
        terraform = terraform_executable,
        tf_vars = tf_vars,
        providers = providers,
        allow_provider_download = True,
        init_on_build = False,
        visibility = visibility,
    )

    # If your module name shares the name of the package directory, create
    # an alias to Terraform without the module name prefix
    if name == paths.basename(native.package_name()):
        native.alias(name = "terraform", actual = ":{}_terraform".format(name))
