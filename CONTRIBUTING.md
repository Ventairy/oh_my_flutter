# Contributing to oh_my_flutter

Thanks for helping keep Flutter utilities focused and dependable.

## Development

```bash
git clone https://github.com/Cataqui/oh_my_flutter.git
cd oh_my_flutter
make setup
make check
```

Use FVM and the root Makefile. Write a regression test for every bug fix, use
`when ..., it should ...` test names, keep one assertion per test case, and
update documentation plus `CHANGELOG.md` for user-visible changes.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/) for every
commit:

```text
<type>[optional scope][optional !]: <description>
```

For example: `feat(colors): add OKLCH conversion`,
`fix(telephony): preserve a leading plus`, or
`docs: clarify installation`. Mark breaking changes with `!` and explain them
in the commit body or a `BREAKING CHANGE:` footer.

Use Discussions for questions and design exploration. Use Issues for
reproducible defects and accepted feature work. By participating, you agree to
follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
