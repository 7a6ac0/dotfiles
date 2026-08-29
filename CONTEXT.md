# Dotfiles

This context describes the managed configuration that turns a macOS machine
into this repository's terminal environment.

## Language

**Managed package**:
A Stow package in this repository whose configuration is reconciled into the
target machine.
_Avoid_: config folder, dotfile bundle

**Machine-local state**:
Configuration or credentials that belong to one target machine and are
intentionally preserved outside the managed packages.
_Avoid_: unmanaged config, local dotfiles

**Machine reconciliation**:
The act of bringing one target machine into the configuration state declared by
the managed packages, while preserving pre-existing machine-specific state.
_Avoid_: setup, bootstrap, installation

**Automated reconciliation**:
The portion of machine reconciliation that the repository can complete without
user interaction.
_Avoid_: fully installed, done

**Reconciliation catalog**:
The single declared inventory of managed packages and the facts needed to
reconcile them on a target machine.
_Avoid_: package lists, installer constants

**Selectable item**:
One unit of the reconciliation catalog a user can accept or decline: a managed
package, or an extra such as the Yazi preview backends or the Nerd Fonts.
_Avoid_: option, module, component

**Selection checklist**:
The interactive list the installer opens so the user can decline selectable
items before any change is made. Every item starts accepted.
_Avoid_: menu, wizard, prompt

**User follow-up**:
A required action that remains after automated reconciliation because it needs
an interactive terminal, an application, or a user preference.
_Avoid_: installer failure, manual installation
