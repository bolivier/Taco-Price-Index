{
  description = "Taco Price Index flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    rubynixpkgs.url = "github:NixOS/nixpkgs/648f70160c03151bc2121d179291337ad6bc564b";
  };
  outputs =
    {
      self,
      nixpkgs,
      rubynixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      rubypkgs = rubynixpkgs.legacyPackages.${system};
    in
    {

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          rubypkgs.ruby_3_2
          openssl_3
          libyaml
          gmp
          rubypkgs.postgresql
          rustc
          cargo
          readline
          libffi
          nodejs
          yarn
        ];
        shellHook = ''
          # Postgres database env vars
          export PGDATA="$PWD/.postgres/data"
          export PGHOST="$PWD/.postgres"
          export PGLOG="$PWD/.postgres/postgres.log"

          # load existing env vars
          set -a
          source .env
          set +a

          # Persist gems locally
          export GEM_HOME="$PWD/.gems"
          export PATH="$GEM_HOME/bin:$PATH"

          mkdir -p "$PGHOST" "$GEM_HOME"

          if [ ! -d "$PGDATA" ]; then
            echo "Initializing local PostgreSQL cluster..."
            initdb --auth=trust --no-locale --encoding=UTF8 "$PGDATA" > /dev/null
            echo "unix_socket_directories = '$PGHOST'" >> "$PGDATA/postgresql.conf"
          fi

          if ! pg_ctl status -D "$PGDATA" > /dev/null 2>&1; then
            echo "Starting PostgreSQL..."
            pg_ctl start -D "$PGDATA" -l "$PGLOG" > /dev/null
          fi

          # Create the role if it doesn't exist
          if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$POSTGRES_USER'" | grep -q 1; then
              echo "Creating role $POSTGRES_USER..."
              psql -d postgres -c "CREATE ROLE $POSTGRES_USER WITH LOGIN PASSWORD '$POSTGRES_PASSWORD' SUPERUSER CREATEDB;"
          fi

          # Create the database if it doesn't exist
          if ! psql -lqt | cut -d \| -f 1 | grep -qw $POSTGRES_DB; then
              echo "Creating database..."
              createdb -O $POSTGRES_USER $POSTGRES_DB
          fi

          echo "Ready to check taco prices 🌮"
        '';
      };
    };
}
