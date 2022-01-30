import click

from evilfish import fish
from evilfish.config import config


@click.command()
# @click.option("--repl", type=bool, default=False)
def cli():
    if not config.debug:
        try:
            with open("./license") as f:
                config.protector = f.read()
        except FileNotFoundError:
            config.protector = click.prompt("License key", type=str)


    fish.run()


if __name__ == '__main__':
    cli()
