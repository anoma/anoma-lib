# keep me alphabetized; non-runtime dependencies at the bottom.
[
  # provides the ArmOpenvm.Verifier NIF (verify_transaction, verify_and_extract,
  # extraction NIFs)
  {:arm_openvm,
   git: "https://github.com/anoma/arm-openvm",
   ref: "e264d9004231072365663da51c54d262333a8914"},
  {:cairo,
   git: "https://github.com/anoma/aarm-cairo",
   ref: "a5a2778a4ad9b2ff40cea471ac777089149b9fda"},
  {:enacl,
   git: "https://github.com/anoma/enacl/",
   ref: "23173637c495b85d56f205e4721cfe5afdef92e9"},
  {:ex_keccak, "~> 0.7.6"},
  {:ex_secp256k1, "~> 0.7.4"},
  {:jason, "~> 1.4"},
  {:memoize, "~> 1.4.3"},
  {:mnesia_rocksdb,
   git: "https://github.com/mariari/mnesia_rocksdb",
   branch: "mariari/bump-rocksdb-9.10"},
  {:murmur, "~> 2.0"},
  {:typed_struct, "~> 0.3.0"},
  # non-runtime dependencies below
  {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
  {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
  {:ex_doc, "~> 0.31", only: [:dev], runtime: false}
]
