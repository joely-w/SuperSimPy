configfile: 'config.yaml'
rule annotateTree:
    input:
        "data/sim.mat.pb",
        "data/labelled_metadata.tsv",
    output:
        "data/result.jsonl.gz"
    shell:
        "usher_to_taxonium --input data/sim.mat.pb --output data/result.jsonl.gz --metadata data/labelled_metadata.tsv --columns location,time"
rule relabelCountries:
    input:
        "data/newick_output_metadata.tsv",
        "population_data/output/census_2013.csv"
    output:
        "data/labelled_metadata.tsv"
    shell:
        "python3 population_data/relabel_populations.py --metadata data/newick_output_metadata.tsv --dictionary population_data/output/manypop_country_ids.csv --output data/labelled_metadata"

rule phastSim:
    input:
        "data/newick_output_tree.nwk"
    output:
        "data/sim.mat.pb"
    shell:
        "{config[executables][phastexec]} --output data/sim --reference {config[phastsim-params][ref]} --scale {config[phastsim-params][scale]} --createMAT --treeFile {input} --eteFormat {config[phastsim-params][ete3_mode]} --mutationRates {config[phastsim-params][mr_model]} {config[phastsim-params][mut_rates]} --createNewick"

rule VGsim:
    output:
        "data/newick_output_tree.nwk",
        "data/newick_output_sample_population.tsv",
        "data/newick_output_metadata.tsv"
    shell:
        "python3 {config[executables][vgexec]} -rt {config[vgsim-params][rt]} -it {config[vgsim-params][it]} -s {config[vgsim-params][samples]} -pm {config[vgsim-params][ppmg]}.pp {config[vgsim-params][ppmg]}.mg -su {config[vgsim-params][sust]}.su -st {config[vgsim-params][sust]}.st --createNewick data/newick_output --writeMigrations data/migrations"

