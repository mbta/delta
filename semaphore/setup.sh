# Fail if any command fails
set -e

export MIX_HOME=$SEMAPHORE_CACHE_DIR/mix
mkdir -p $MIX_HOME

export ASDF_DATA_DIR=$SEMAPHORE_CACHE_DIR/.asdf

if [[ ! -d $ASDF_DATA_DIR ]]; then
  mkdir -p $ASDF_DATA_DIR
  git clone https://github.com/asdf-vm/asdf.git $ASDF_DATA_DIR --branch v0.8.0
fi

source $ASDF_DATA_DIR/asdf.sh
asdf update

asdf plugin-add erlang || true
asdf plugin-add elixir || true
asdf plugin-update --all
asdf install

mix local.hex --force
mix local.rebar --force
mix deps.get
