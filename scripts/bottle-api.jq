map(.[]) as $reports
| ([$reports[].bottle.tags[].tab.runtime_dependencies[].full_name] | unique) as $dependencies
| {
    name: $reports[0].formula.name,
    tap: $tap,
    versions: {stable: $reports[0].formula.pkg_version},
    dependencies: $dependencies,
    # Homebrew configures these runtimes on older Linux hosts. Mise needs
    # them in the x86-64 dependency closure so its loader can use them.
    variations: {
      x86_64_linux: {dependencies: ($dependencies + ["gcc", "glibc"] | unique)}
    },
    post_install_steps: ($formula_info[0].formulae[0].post_install_steps | select(length > 0)),
    bottle: {
      stable: {
        rebuild: $reports[0].bottle.rebuild,
        files: ([
          $reports[].bottle as $bottle
          | $bottle.tags | to_entries[]
          | .value = {
              cellar: (.value.cellar // $bottle.cellar),
              url: ($bottle.root_url + "/" + .value.filename),
              sha256: .value.sha256
            }
        ] | from_entries)
      }
    }
  }
