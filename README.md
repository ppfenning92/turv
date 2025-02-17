# Turv - Directory-Based Environment Loader

Turv is a simple yet powerful tool that automatically loads environment variables based on the current directory. It helps developers seamlessly switch between projects with different configurations, minimizing conflicts and improving workflow efficiency.

## Features

- **Automatic Environment Management** – Loads environment variables upon entering a directory and unloads them when leaving.
- **Approval System** – Prompts users before sourcing an environment file for the first time, ensuring security.
- **Flexible Configuration Formats** – Supports JSON, YAML, and (future) TOML for approval tracking.
- **Shell Compatibility** – Works with Bash and Zsh.
- **Logging & Debugging** – Provides logs for troubleshooting and debugging.
- **Minimal Dependencies** – Requires either `jq` or `yq` for configuration handling.

## Why Use Turv?

Developers frequently work with different tools, cloud environments, and repositories, leading to potential conflicts in environment variables and aliases. Turv provides a structured way to manage these variables on a per-project basis. Unlike some alternatives, Turv includes a built-in approval system to prevent unintended execution of environment files.

Common use cases include:
- Managing credentials and API keys for multiple GitHub and GitLab instances.
- Handling environment-specific configurations for Terraform, OpenTofu, or cloud services.
- Integrating with secret management tools like Vault CLI or 1Password CLI.

Inspired by `direnv`, `autoenv`, and `dirsh`, Turv focuses on security and simplicity.

## Installation

### Oh My Zsh

To install Turv as a plugin for Oh My Zsh, run:

```sh
git clone https://gitlab.com/patrick.pfenning.92/turv.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/turv
```

Then, add `turv` to your `.zshrc` plugins list:

```sh
plugins=(... turv)
```

Restart your shell or reload your configuration with `source ~/.zshrc`.

### Manual Installation

For Bash or Zsh, add the following line to your shell configuration file:

```sh
source /path/to/turv.sh
```

Ensure that `turv` is loaded before other environment configurations. Additionally, consider adding the environment file (e.g., `.envrc`) to your global `.gitignore` to avoid committing sensitive data.

## Configuration

Turv settings can be controlled using environment variables. Add these to `~/.zshenv` or `~/.bashrc` as needed:

| Variable             | Default  | Description                                        |
|---------------------|----------|--------------------------------------------------|
| `TURV_CONFIG_FORMAT` | `yaml`   | Format for approval tracking (json, yaml, toml)  |
| `TURV_ENV_FILE`      | `.envrc` | Name of the file containing environment variables |
| `TURV_ASSUME_YES`    | unset    | Automatically approve sourcing                   |
| `TURV_DEBUG`         | unset    | Enable debug logs                                |
| `TURV_QUIET`         | unset    | Suppress log output                             |

Setting `TURV_ASSUME_YES=1` allows Turv to load environment files without prompting.

## Attributions

Turv is inspired by:

- [direnv](https://github.com/direnv/direnv)
- [autoenv](https://github.com/hyperupcall/autoenv)
- [dirsh gist](https://gist.github.com/87c59acf3b53cf1911bc6e3a8055afbf)
- [dirsh blogpost](https://blog.tarkalabs.com/dirsh-5d4650008c65)

