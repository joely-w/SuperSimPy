configfile: 'config.yaml'

rule VGsim:
    input:
        expand("{param_dir}.{extension}",param_dir=config['population_params'],extension=['pp', 'mg'])
    output:
        newick_tree=expand("{output_dir}/newick_output_tree.nwk",output_dir=config['output_directory']),
        locations=expand("{output_dir}/newick_output_sample_population.tsv",output_dir=config['output_directory']),
        metadata=expand("{output_dir}/newick_output_metadata.tsv",output_dir=config['output_directory']),
    threads: 4,
    shell:
        "python3 ./bin/VGsim_cmd.py -it {config[vg_iterations]} -s {config[vg_samples]} -pm {config[population_params]}.pp {config[population_params]}.mg --createNewick {config[output_directory]}/newick_output --writeMigrations {config[output_directory]}/migrations"

rule timeScale:
    input:
        rules.VGsim.output.newick_tree,
        rules.VGsim.output.metadata
    output:
        genealogy=expand("{output_dir}/genealogy.nwk",output_dir=config['output_directory']),
        dated_metadata=expand("{output_dir}/dated_metadata.csv",output_dir=config['output_directory']),
    shell:
        "python3 ./pipeline_processing/scale_genealogy_time.py --folder={config[output_directory]}"

rule relabelCountries:
    input:
        rules.timeScale.output.dated_metadata,
        "pre_processing/data_sources/census_2013.csv"
    output:
        complete_metadata=expand("{output_dir}/dated_country_labelled_metadata.tsv",output_dir=config[
            'output_directory'])
    shell:
        "python3 pipeline_processing/relabel_populations.py --metadata {config[output_directory]}/dated_metadata.csv --dictionary parameters/manypop_country_ids.csv --output {config[output_directory]}/dated_country_labelled_metadata"

rule phastSim:
    input:
        rules.timeScale.output.genealogy,
    output:
        sim_pb=expand("{output_dir}/sim.mat.pb",output_dir=config['output_directory']),
        sim_tree=expand("{output_dir}/sim.tree",output_dir=config['output_directory']),
    threads: 4,
    shell:
        "phastSim --output sim --outpath {config[output_directory]}/ --reference {config[phastsim-params][ref]} --scale {config[phastsim-params][scale]} --createMAT --treeFile {input} --eteFormat {config[phastsim-params][ete3_mode]} --mutationRates {config[phastsim-params][mr_model]} {config[phastsim-params][mut_rates]} --createNewick"

rule timeToGeneticDistance:
    input:
        rules.phastSim.output.sim_tree,
        rules.relabelCountries.output.complete_metadata
    output:
        substitution_tree=expand("{output_dir}/sim.substitutions.tree",output_dir=config['output_directory']),
        datefile=expand("{output_dir}/datefile.txt",output_dir=config['output_directory']),
    shell:
        "python3 ./pipeline_processing/scale_time_to_subs.py --datapath {config[output_directory]}"

rule annotateTree:
    input:
        rules.phastSim.output.sim_pb,
        rules.relabelCountries.output.complete_metadata,
    output:
        annotated_tree=expand("{output_dir}/fully_annotated_tree.jsonl.gz",output_dir=config['output_directory'])
    shell:
        "usher_to_taxonium --input {config[output_directory]}/sim.mat.pb --output {config[output_directory]}/fully_annotated_tree.jsonl.gz --metadata {config[output_directory]}/dated_country_labelled_metadata.tsv --columns location"

rule visualisations:
    input:
        rules.phastSim.output.sim_tree,
        rules.timeToGeneticDistance.output.substitution_tree,
    output:
        time_image=expand("{output_dir}/sim.tree distributions.png",output_dir=config['output_directory']),
        substitutions_image=expand("{output_dir}/sim.substitutions.tree distributions.png",output_dir=config[
            'output_directory'])
    shell:
        "python3 post_processing/branch_distributions.py --folder={config[output_directory]}"

rule all:
    default_target: True,
    input:
        rules.annotateTree.output.annotated_tree,
        rules.timeToGeneticDistance.output.substitution_tree,
        rules.timeToGeneticDistance.output.datefile,
        rules.phastSim.output.sim_pb,
        rules.phastSim.output.sim_tree,
        rules.VGsim.output.newick_tree,
        rules.VGsim.output.locations,
        rules.relabelCountries.output.complete_metadata,
        rules.visualisations.output.time_image,
        rules.visualisations.output.substitutions_image
