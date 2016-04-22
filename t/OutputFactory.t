# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin qw($Bin);

use lib $Bin;
use VEPTestingConfig;
my $test_cfg = VEPTestingConfig->new();

my $cfg_hash = $test_cfg->base_testing_cfg;

## BASIC TESTS
##############

# use test
use_ok('Bio::EnsEMBL::VEP::OutputFactory');


## WE NEED A RUNNER
###################

# use test
use_ok('Bio::EnsEMBL::VEP::Runner');

my $runner = Bio::EnsEMBL::VEP::Runner->new({
  %$cfg_hash,
  input_file => $test_cfg->{test_vcf},
  check_existing => 1,
  dir => $test_cfg->{cache_root_dir}.'/sereal',
});
ok($runner, 'new is defined');

is(ref($runner), 'Bio::EnsEMBL::VEP::Runner', 'check class');

ok($runner->init, 'init');


my $of = Bio::EnsEMBL::VEP::OutputFactory->new({config => $runner->config});
ok($of, 'new is defined');
is(ref($of), 'Bio::EnsEMBL::VEP::OutputFactory', 'check class');

my $ib = $runner->get_InputBuffer;
$ib->next();
$_->annotate_InputBuffer($ib) for @{$runner->get_all_AnnotationSources};
$ib->finish_annotation();

my $vf = $ib->buffer->[0];
my $exp = {
  'Existing_variation' => [
    'rs142513484'
  ]
};

is_deeply(
  $of->add_colocated_variant_info($vf, {}),
  $exp,
  'add_colocated_variant_info',
);



## frequency tests
##################

$of->{gmaf} = 1;
$exp->{GMAF} = ['T:0.0010'];
is_deeply(
  $of->add_colocated_variant_info($vf, {}),
  $exp,
  'add_colocated_variant_info - gmaf',
);

$of->{maf_1kg} = 1;
$exp->{AFR_MAF} = ['T:0.0030'];
$exp->{AMR_MAF} = ['T:0.0014'];
$exp->{EAS_MAF} = ['T:0.0000'];
$exp->{EUR_MAF} = ['T:0.0000'];
$exp->{SAS_MAF} = ['T:0.0000'];
is_deeply(
  $of->add_colocated_variant_info($vf, {}),
  $exp,
  'add_colocated_variant_info - maf_1kg',
);

$of->{gmaf} = 0;
$of->{maf_1kg} = 0;

$ib = get_annotated_buffer({
  check_existing => 1,
  input_file => $test_cfg->create_input_file([qw(21 25891796 . C T . . .)])
});
$of->{maf_exac} = 1;

is_deeply(
  $of->add_colocated_variant_info($ib->buffer->[0], {}),
  {
    'ExAC_OTH_MAF' => [
      'T:0.001101'
    ],
    'ExAC_Adj_MAF' => [
      'T:5.768e-05'
    ],
    'ExAC_AFR_MAF' => [
      'T:0'
    ],
    'ExAC_AMR_MAF' => [
      'T:0.0003457'
    ],
    'PHENO' => [
      1,
      1
    ],
    'Existing_variation' => [
      'rs63750066',
      'CM930033'
    ],
    'CLIN_SIG' => [
      'not_provided,pathogenic'
    ],
    'ExAC_NFE_MAF' => [
      'T:2.998e-05'
    ],
    'ExAC_SAS_MAF' => [
      'T:0'
    ],
    'ExAC_FIN_MAF' => [
      'T:0'
    ],
    'ExAC_EAS_MAF' => [
      'T:0'
    ],
    'ExAC_MAF' => [
      'T:5.765e-05'
    ]
  },
  'add_colocated_variant_info - maf_exac, pheno, clin_sig',
);
$of->{maf_exac} = 0;

$ib = get_annotated_buffer({
  check_existing => 1,
  input_file => $test_cfg->create_input_file([qw(21 25975223 . G A . . .)])
});

$of->{maf_esp} = 1;
is_deeply(
  $of->add_colocated_variant_info($ib->buffer->[0], {}),
  {
    'Existing_variation' => [
      'rs148180403',
    ],
    'AA_MAF' => [
      'A:0',
    ],
    'EA_MAF' => [
      'A:0.0008',
    ],
  },
  'add_colocated_variant_info - maf_esp',
);
$of->{maf_esp} = 0;



## pubmed
#########

$ib = get_annotated_buffer({
  check_existing => 1,
  input_file => $test_cfg->create_input_file([qw(21 25272769 . C T . . .)])
});

$of->{pubmed} = 1;
is_deeply(
  $of->add_colocated_variant_info($ib->buffer->[0], {}),
  {
    'Existing_variation' => [
      'rs9977253',
    ],
    'PHENO' => [
      1
    ],
    'PUBMED' => [
      '20708005',
    ],
  },
  'add_colocated_variant_info - pubmed',
);
$of->{pubmed} = 0;


## somatic
##########

$ib = get_annotated_buffer({
  check_existing => 1,
  input_file => $test_cfg->create_input_file([qw(21 25891785 . G A . . .)])
});

is_deeply(
  $of->add_colocated_variant_info($ib->buffer->[0], {}),
  {
    'Existing_variation' => [
      'rs145564988',
      'COSM1029633',
    ],
    'SOMATIC' => [
      0, 1,
    ],
    'PHENO' => [
      0, 1,
    ],
  },
  'add_colocated_variant_info - somatic',
);



## VariationFeature_to_output_hash
##################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
});

is_deeply(
  $of->VariationFeature_to_output_hash($ib->buffer->[0]),
  {
    'Uploaded_variation' => 'rs142513484',
    'Location' => '21:25585733'
  },
  'VariationFeature_to_output_hash'
);

$of->{variant_class} = 1;
is_deeply(
  $of->VariationFeature_to_output_hash($ib->buffer->[0]),
  {
    'Uploaded_variation' => 'rs142513484',
    'Location' => '21:25585733',
    'VARIANT_CLASS' => 'SNV',
  },
  'VariationFeature_to_output_hash - variant_class'
);
$of->{variant_class} = 0;

no warnings 'qw';
$ib = get_annotated_buffer({
  input_file => $test_cfg->create_input_file([
    ['##fileformat=VCFv4.1'],
    [qw(#CHROM POS ID REF ALT QUAL FILTER INFO FORMAT dave barry jeff)],
    [qw(21 25587759 indtest A G . . . GT 0|1 1/1 0/0)],
  ]),
  individual => 'dave',
});


$of->{individual} = ['dave'];
is_deeply(
  $of->VariationFeature_to_output_hash($ib->buffer->[0]),
  {
    'Uploaded_variation' => 'indtest',
    'Location' => '21:25587759',
    'IND' => 'dave',
    'ZYG' => 'HET',
  },
  'VariationFeature_to_output_hash - individual'
);
delete($of->{individual});

$of->get_all_output_hashes_by_VariationFeature($ib->buffer->[0]);



## pick_worst_VariationFeatureOverlapAllele
###########################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
  regulatory => 1,
});
my @vfoas =
  map {@{$_->get_all_alternate_VariationFeatureOverlapAlleles}}
  @{$ib->buffer->[0]->get_all_VariationFeatureOverlaps};

is(
  $of->pick_worst_VariationFeatureOverlapAllele(\@vfoas)->feature->stable_id,
  'ENST00000307301',
  'pick_worst_VariationFeatureOverlapAllele - default'
);

my $orig_order = $of->{pick_order};

$of->{pick_order} = ['rank'];
is(
  $of->pick_worst_VariationFeatureOverlapAllele(\@vfoas)->feature->stable_id,
  'ENST00000352957',
  'pick_worst_VariationFeatureOverlapAllele - rank'
);

$of->{pick_order} = ['appris'];
is(
  $of->pick_worst_VariationFeatureOverlapAllele(\@vfoas)->feature->stable_id,
  'ENST00000352957',
  'pick_worst_VariationFeatureOverlapAllele - appris'
);

$of->{pick_order} = ['canonical','biotype'];
is(
  $of->pick_worst_VariationFeatureOverlapAllele(\@vfoas)->feature->stable_id,
  'ENST00000307301',
  'pick_worst_VariationFeatureOverlapAllele - canonical,biotype'
);

$of->{pick_order} = $orig_order;


## pick_VariationFeatureOverlapAllele_per_gene
##############################################

is_deeply(
  [sort map {$_->feature->stable_id} @{$of->pick_VariationFeatureOverlapAllele_per_gene(\@vfoas)}],
  ['ENSR00001963192', 'ENST00000307301', 'ENST00000567517'],
  'pick_VariationFeatureOverlapAllele_per_gene'
);

$of->{pick_order} = ['rank'];
is_deeply(
  [sort map {$_->feature->stable_id} @{$of->pick_VariationFeatureOverlapAllele_per_gene(\@vfoas)}],
  ['ENSR00001963192', 'ENST00000352957', 'ENST00000567517'],
  'pick_VariationFeatureOverlapAllele_per_gene - change pick_order'
);
$of->{pick_order} = $orig_order;


## filter_VariationFeatureOverlapAlleles
########################################

is(scalar @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}, scalar @vfoas, 'filter_VariationFeatureOverlapAlleles - no filter');

$of->{pick} = 1;
is_deeply(
  [sort map {$_->feature->stable_id} @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}],
  ['ENST00000307301'],
  'filter_VariationFeatureOverlapAlleles - pick'
);
$of->{pick} = 0;

$of->{per_gene} = 1;
is_deeply(
  [sort map {$_->feature->stable_id} @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}],
  ['ENSR00001963192', 'ENST00000307301', 'ENST00000567517'],
  'filter_VariationFeatureOverlapAlleles - per_gene'
);
$of->{per_gene} = 0;

$of->{flag_pick} = 1;
is(
  scalar @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)},
  scalar @vfoas,
  'filter_VariationFeatureOverlapAlleles - flag_pick count'
);
is_deeply(
  [
    sort
    map {$_->feature->stable_id}
    grep {$_->{PICK}}
    @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}
  ],
  ['ENST00000307301'],
  'filter_VariationFeatureOverlapAlleles - flag_pick check'
);
$of->{flag_pick} = 0;

# per allele tests
$ib = get_annotated_buffer({
  input_file => $test_cfg->create_input_file([qw(21 25585733 rs142513484 C G,T . . .)]),
  regulatory => 1,
});
@vfoas =
  map {@{$_->get_all_alternate_VariationFeatureOverlapAlleles}}
  @{$ib->buffer->[0]->get_all_VariationFeatureOverlaps};

$of->{pick_allele} = 1;
is_deeply(
  [
    sort
    map {$_->variation_feature_seq.':'.$_->feature->stable_id}
    @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}
  ],
  ['G:ENST00000307301', 'T:ENST00000307301'],
  'filter_VariationFeatureOverlapAlleles - pick_allele'
);
$of->{pick_allele} = 0;

$of->{flag_pick_allele} = 1;
is(
  scalar @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)},
  scalar @vfoas,
  'filter_VariationFeatureOverlapAlleles - flag_pick_allele count'
);
is_deeply(
  [
    sort
    map {$_->variation_feature_seq.':'.$_->feature->stable_id}
    grep {$_->{PICK}}
    @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}
  ],
  ['G:ENST00000307301', 'T:ENST00000307301'],
  'filter_VariationFeatureOverlapAlleles - flag_pick_allele check'
);
$of->{flag_pick_allele} = 0;

$of->{pick_allele_gene} = 1;
is_deeply(
  [
    sort
    map {$_->variation_feature_seq.':'.$_->feature->stable_id}
    @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}
  ],
  [
    'G:ENSR00001963192', 'G:ENST00000307301', 'G:ENST00000567517',
    'T:ENSR00001963192', 'T:ENST00000307301', 'T:ENST00000567517'
  ],
  'filter_VariationFeatureOverlapAlleles - pick_allele_gene'
);
$of->{pick_allele_gene} = 0;

$of->{flag_pick_allele_gene} = 1;
is(
  scalar @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)},
  scalar @vfoas,
  'filter_VariationFeatureOverlapAlleles - flag_pick_allele_gene count'
);
is_deeply(
  [
    sort
    map {$_->variation_feature_seq.':'.$_->feature->stable_id}
    grep {$_->{PICK}}
    @{$of->filter_VariationFeatureOverlapAlleles(\@vfoas)}
  ],
  [
    'G:ENSR00001963192', 'G:ENST00000307301', 'G:ENST00000567517',
    'T:ENSR00001963192', 'T:ENST00000307301', 'T:ENST00000567517'
  ],
  'filter_VariationFeatureOverlapAlleles - flag_pick_allele_gene check'
);
$of->{flag_pick_allele_gene} = 0;



## get_all_VariationFeatureOverlapAlleles
#########################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
});

is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  3,
  'get_all_VariationFeatureOverlapAlleles'
);

$of->{coding_only} = 1;
is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  1,
  'get_all_VariationFeatureOverlapAlleles - coding_only'
);
$of->{coding_only} = 0;

$ib = get_annotated_buffer({
  input_file => $test_cfg->create_input_file([qw(21 25832817 . C A . . .)]),
});

is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  1,
  'get_all_VariationFeatureOverlapAlleles - no_intergenic off'
);

$of->{no_intergenic} = 1;
is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  0,
  'get_all_VariationFeatureOverlapAlleles - no_intergenic on'
);
$of->{no_intergenic} = 0;


$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
  individual => 'all',
});

is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  0,
  'get_all_VariationFeatureOverlapAlleles - process_ref_homs off'
);

$of->{process_ref_homs} = 1;
is(
  scalar @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])},
  3,
  'get_all_VariationFeatureOverlapAlleles - process_ref_homs on'
);
$of->{process_ref_homs} = 0;



## VariationFeatureOverlapAllele_to_output_hash
###############################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
});

my $vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[0];

is_deeply(
  $of->VariationFeatureOverlapAllele_to_output_hash($vfoa),
  {
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      '3_prime_UTR_variant'
    ],
    'Allele' => 'T'
  },
  'VariationFeatureOverlapAllele_to_output_hash'
);

$of->{allele_number} = 1;
is_deeply(
  $of->VariationFeatureOverlapAllele_to_output_hash($vfoa),
  {
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      '3_prime_UTR_variant'
    ],
    'Allele' => 'T',
    'ALLELE_NUM' => 1,
  },
  'VariationFeatureOverlapAllele_to_output_hash - allele_number'
);
$of->{allele_number} = 0;

$of->{flag_pick} = 1;
($vfoa) = grep {$_->{PICK}} @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])};
is_deeply(
  $of->VariationFeatureOverlapAllele_to_output_hash($vfoa),
  {
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      '3_prime_UTR_variant'
    ],
    'Allele' => 'T',
    'PICK' => 1,
  },
  'VariationFeatureOverlapAllele_to_output_hash - pick'
);
$of->{flag_pick} = 0;



## BaseTranscriptVariationAllele_to_output_hash
###############################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->{test_vcf},
});

$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[2];

is_deeply(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      'upstream_gene_variant'
    ],
    'Feature_type' => 'Transcript',
    'Feature' => 'ENST00000567517',
    'Allele' => 'T',
    'Gene' => 'ENSG00000260583',
    'DISTANCE' => 2407,
  },
  'BaseTranscriptVariationAllele_to_output_hash'
);

($vf) = grep {$_->{variation_name} eq 'rs199510789'} @{$ib->buffer};
($vfoa) = grep {$_->feature->stable_id eq 'ENST00000419219'} @{$of->get_all_VariationFeatureOverlapAlleles($vf)};

is_deeply(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      'downstream_gene_variant'
    ],
    'Feature_type' => 'Transcript',
    'Feature' => 'ENST00000419219',
    'Allele' => 'T',
    'Gene' => 'ENSG00000154719',
    'FLAGS' => 'cds_end_NF',
    'DISTANCE' => 3953,
  },
  'BaseTranscriptVariationAllele_to_output_hash - check transcript FLAGS'
);

$of->{numbers} = 1;
$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[1];
is(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa)->{EXON},
  '10/10',
  'BaseTranscriptVariationAllele_to_output_hash - exon numbers'
);

($vf) = grep {$_->{variation_name} eq 'rs187353664'} @{$ib->buffer};
($vfoa) = grep {$_->feature->stable_id eq 'ENST00000352957'} @{$of->get_all_VariationFeatureOverlapAlleles($vf)};

is(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa)->{INTRON},
  '9/9',
  'BaseTranscriptVariationAllele_to_output_hash - intron numbers'
);
$of->{numbers} = 0;

$of->{domains} = 1;
($vf) = grep {$_->{variation_name} eq 'rs116645811'} @{$ib->buffer};
($vfoa) = grep {$_->feature->stable_id eq 'ENST00000307301'} @{$of->get_all_VariationFeatureOverlapAlleles($vf)};
is_deeply(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa)->{DOMAINS},
  ['Low_complexity_(Seg):seg'],
  'BaseTranscriptVariationAllele_to_output_hash - domains'
);
$of->{domains} = 0;

$of->{symbol} = 1;
$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[0];
is_deeply(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'HGNC_ID' => 'HGNC:14027',
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      '3_prime_UTR_variant'
    ],
    'SYMBOL' => 'MRPL39',
    'Feature_type' => 'Transcript',
    'SYMBOL_SOURCE' => 'HGNC',
    'Allele' => 'T',
    'Gene' => 'ENSG00000154719',
    'Feature' => 'ENST00000307301'
  },
  'BaseTranscriptVariationAllele_to_output_hash - symbol'
);
$of->{symbol} = 0;

$of->{gene_phenotype} = 1;
($vf) = grep {$_->{variation_name} eq 'rs145277462'} @{$ib->buffer};
($vfoa) = grep {$_->feature->stable_id eq 'ENST00000346798'} @{$of->get_all_VariationFeatureOverlapAlleles($vf)};
is(
  $of->BaseTranscriptVariationAllele_to_output_hash($vfoa)->{GENE_PHENO},
  1,
  'BaseTranscriptVariationAllele_to_output_hash - gene_phenotype'
);
$of->{gene_phenotype} = 0;

# we can test these ones en-masse
my @flags = (
  [qw(ccds        CCDS      CCDS33522.1)],
  [qw(xref_refseq RefSeq    NM_080794.3)],
  [qw(protein     ENSP      ENSP00000305682)],
  [qw(canonical   CANONICAL YES)],
  [qw(biotype     BIOTYPE   protein_coding)],
  [qw(tsl         TSL       5)],
  [qw(appris      APPRIS    A2)],
  [qw(uniprot     SWISSPROT Q9NYK5)],
  [qw(uniprot     UNIPARC   UPI00001AEAC0)],
);
my $method = 'BaseTranscriptVariationAllele_to_output_hash';
$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[0];

foreach my $flag(@flags) {
  $of->{$flag->[0]} = 1;
  is($of->$method($vfoa)->{$flag->[1]}, $flag->[2], $method.' - '.$flag->[0]);
  $of->{$flag->[0]} = 0;
}


## TranscriptVariationAllele_to_output_hash
###########################################

$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[1];

is_deeply(
  $of->TranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'IMPACT' => 'MODERATE',
    'Consequence' => [
      'missense_variant'
    ],
    'Feature_type' => 'Transcript',
    'Allele' => 'T',
    'CDS_position' => 991,
    'Gene' => 'ENSG00000154719',
    'cDNA_position' => 1033,
    'Protein_position' => 331,
    'Amino_acids' => 'A/T',
    'Feature' => 'ENST00000352957',
    'Codons' => 'Gca/Aca'
  },
  'TranscriptVariationAllele_to_output_hash'
);

$of->{total_length} = 1;
is_deeply(
  $of->TranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'IMPACT' => 'MODERATE',
    'Consequence' => [
      'missense_variant'
    ],
    'Feature_type' => 'Transcript',
    'Allele' => 'T',
    'CDS_position' => '991/1017',
    'Gene' => 'ENSG00000154719',
    'cDNA_position' => '1033/1110',
    'Protein_position' => '331/338',
    'Amino_acids' => 'A/T',
    'Feature' => 'ENST00000352957',
    'Codons' => 'Gca/Aca'
  },
  'TranscriptVariationAllele_to_output_hash - total_length'
);
$of->{total_length} = 0;

$vfoa = $of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])->[0];
is_deeply(
  $of->TranscriptVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => -1,
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      '3_prime_UTR_variant'
    ],
    'Feature_type' => 'Transcript',
    'Allele' => 'T',
    'Gene' => 'ENSG00000154719',
    'cDNA_position' => 1122,
    'Feature' => 'ENST00000307301'
  },
  'TranscriptVariationAllele_to_output_hash - non-coding'
);

@flags = (
  [qw(sift     p SIFT     tolerated_low_confidence)],
  [qw(sift     s SIFT     0.17)],
  [qw(sift     b SIFT     tolerated_low_confidence\(0.17\))],
  [qw(polyphen p PolyPhen benign)],
  [qw(polyphen s PolyPhen 0.021)],
  [qw(polyphen b PolyPhen benign\(0.021\))],
);
$method = 'TranscriptVariationAllele_to_output_hash';
($vf) = grep {$_->{variation_name} eq 'rs142513484'} @{$ib->buffer};
($vfoa) = grep {$_->feature->stable_id eq 'ENST00000352957'} @{$of->get_all_VariationFeatureOverlapAlleles($vf)};

foreach my $flag(@flags) {
  $of->{$flag->[0]} = $flag->[1];
  is($of->$method($vfoa)->{$flag->[2]}, $flag->[3], $method.' - '.$flag->[0].' '.$flag->[1]);
  $of->{$flag->[0]} = 0;
}



## RegulatoryFeatureVariationAllele_to_output_hash
##################################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->create_input_file([qw(21 25734924 . C T . . .)]),
  regulatory => 1,
});

($vfoa) = grep {ref($_) =~ /Regulatory/} @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])};

is_deeply(
  $of->RegulatoryFeatureVariationAllele_to_output_hash($vfoa),
  {
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      'regulatory_region_variant'
    ],
    'Feature_type' => 'RegulatoryFeature',
    'BIOTYPE' => 'promoter',
    'Feature' => 'ENSR00001963212',
    'Allele' => 'T'
  },
  'RegulatoryFeatureVariationAllele_to_output_hash'
);

$of->{cell_type} = ['HUVEC'];
is_deeply(
  $of->RegulatoryFeatureVariationAllele_to_output_hash($vfoa)->{CELL_TYPE},
  ['HUVEC:Promoter'],
  'RegulatoryFeatureVariationAllele_to_output_hash - cell_type'
);
$of->{cell_type} = undef;




## MotifFeatureVariationAllele_to_output_hash
#############################################

$ib = get_annotated_buffer({
  input_file => $test_cfg->create_input_file([qw(21 25734924 . C T . . .)]),
  regulatory => 1,
});

($vfoa) = grep {ref($_) =~ /Motif/} @{$of->get_all_VariationFeatureOverlapAlleles($ib->buffer->[0])};

is_deeply(
  $of->MotifFeatureVariationAllele_to_output_hash($vfoa),
  {
    'STRAND' => 1,
    'IMPACT' => 'MODIFIER',
    'Consequence' => [
      'TF_binding_site_variant'
    ],
    'MOTIF_POS' => 7,
    'Feature_type' => 'MotifFeature',
    'MOTIF_NAME' => 'Name/Accession_association_Egr1:MA0162.2',
    'Allele' => 'T',
    'Feature' => 'MA0162.2',
    'HIGH_INF_POS' => 'Y',
    'MOTIF_SCORE_CHANGE' => '-0.097'
  },
  'MotifFeatureVariationAllele_to_output_hash'
);


$of->{cell_type} = ['MultiCell'];
is_deeply(
  $of->MotifFeatureVariationAllele_to_output_hash($vfoa)->{CELL_TYPE},
  ['MultiCell:Promoter'],
  'MotifFeatureVariationAllele_to_output_hash - cell_type'
);
$of->{cell_type} = undef;



# done
done_testing();

sub get_annotated_buffer {
  my $tmp_cfg = shift;

  my $runner = Bio::EnsEMBL::VEP::Runner->new({
    %$cfg_hash,
    dir => $test_cfg->{cache_root_dir}.'/sereal',
    %$tmp_cfg,
  });

  $runner->init;

  my $ib = $runner->get_InputBuffer;
  $ib->next();
  $_->annotate_InputBuffer($ib) for @{$runner->get_all_AnnotationSources};
  $ib->finish_annotation();

  return $ib;
}