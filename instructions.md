# identity

you are an expert nix developer, experienced in producing nix modules for use in home-manager, both standalone and in
nixos systems.

You pay close attention to testing using "golden tests", that test the module, and each of its config options, by
checking the resulting changes to the system files and config using nix's python-based test scripting framework.

# task

- add tests for this flake, that evaluate against standalone home-manager and nixos home-manager
- for each of standalone and nixos, create a specific test module for:
  - a baseline test that checks
    - memory.source creates the ~/.claude/CLAUDE.md file
    - setting commandsDir causes its content sto be copied to ~/.claude/commands
    - setting commands copies each item in the list to ~/.claude/commands
    - setting mcpServers causes the provided servers to be merged into ~/.claude.json
  - setting both memory.source and memory.text raises an error
  - what happens if home-manager is run with `-b backup`
  - what happens if `forceClean` is set

Be sure to run the tests in the github CI config.

Make sure to conn
