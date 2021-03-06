# 
# Author: Miquel Anglada Girotto
# Contact: miquel [dot] anglada [at] crg [dot] eu
#
# Script purpose
# --------------
# Make figure of correlations between aneuploidy scores 
# with gene expression by cancer and sample types.
#

# libraries
require(readr)
require(ggpubr)
require(dplyr)
require(tidyr)
require(reshape2)
require(latex2exp)
require(gtools)
require(writexl)
require(latex2exp)

GENE_OI = 'TTLL11'
ORDER_OI = c('LUSC','UCEC','BRCA','STAD','LUAD','KIRP','THCA','KICH','COAD','LIHC','HNSC','PRAD','KIRC')

# variables
ROOT = here::here()
RESULTS_DIR = file.path(ROOT,'results')

WIDTH = 7.5
HEIGHT = 4
BASE_SIZE = 10

FONT_SIZE = 7 # pt
FONT_FAMILY = 'helvetica'

N_SAMPLE = 1000

# inputs
correlations_aneuploidy_file = file.path(RESULTS_DIR,'files','correlation-genexpr_aneuploidy.tsv') 

# outputs
output_file = file.path(RESULTS_DIR,'figures','aneuploidy_correlations.pdf')
output_figdata = file.path(RESULTS_DIR,'files','figdata-aneuploidy_correlations.xlsx')

##### FUNCTIONS ######
make_plot = function(df, plt_title, gene_oi=GENE_OI, y_lab_pos=-0.6){
    # plot spearman correlation values as stripchart and violin
    # highlighting TTLL11 and adding the p-value of the Z-score of 
    # TTLL11 as labels
    
    ## prepare pvalues in gene OI
    stat.test = df %>% filter(gene == GENE_OI) %>% 
        mutate(
            p=pvalue, 
            p.format=format.pval(pvalue,1),
            p.signif=stars.pval(pvalue),
            group1=NA,
            group2=NA)

    ## plot
    plt = ggviolin(df, x='cancer_type', y='value', color='darkgrey', alpha=0.5, lwd=0.2) +
    geom_boxplot(width=0.1, outlier.shape = NA, lwd=0.1) + 
    geom_point(data = df %>% filter(gene == 'TTLL11'), color='darkred', size=1) + 
    xlab(element_blank()) + ylab(element_blank()) + ggtitle(element_blank()) + 
    stat_pvalue_manual(stat.test, x = 'cancer_type', y.position = y_lab_pos, label = 'p.signif')
    plt = ggpar(plt, font.tickslab = c(BASE_SIZE))
    return(plt)
}

##### Data wrangling ######
# load data
correlations_aneuploidy = read_tsv(correlations_aneuploidy_file)

# transform to long format
correlations_aneuploidy = correlations_aneuploidy %>% 
    melt() %>% 
    rename(cancer_type = variable) %>% 
    mutate(sample_type = 'Primary Tumor', score_type = 'Aneuploidy') 


# filter
correlations_aneuploidy = correlations_aneuploidy %>% filter(cancer_type %in% ORDER_OI)

plts = list()

# init
df = correlations_aneuploidy

# compute z-scores and pvalues by cancer
df = df %>% 
    group_by(cancer_type) %>% 
    mutate(z_score=as.numeric(scale(value)),
           pvalue=pnorm(-abs(z_score))) %>% 
    ungroup()

# change group order
df = df %>% mutate(cancer_type = factor(cancer_type, levels=ORDER_OI))
df = df[order(df$cancer_type),]

# plot by cancer
df = df %>% drop_na()
plt_title = 'Gene Expression and Aneuploidy Score'
gene_oi = GENE_OI
plts[['aneuploidy_bycancer']] = make_plot(df, plt_title, gene_oi, -0.7)

# prepare pancancer
df_pancan = df %>% 
    group_by(gene) %>% 
    summarize(value=median(value)) %>% 
    ungroup() %>% 
    mutate(z_score=as.numeric(scale(value)), pvalue=pnorm(-abs(z_score))) %>% 
    mutate(cancer_type='PANCAN')

# plot pancancer
plts[['aneuploidy_pancancer']] = make_plot(df_pancan, plt_title, gene_oi, -0.4)

# compose figure
widths_cancer_type = c(1.15,0.13)

plt = ggarrange(
    plts[['aneuploidy_bycancer']] + 
        ylab('Spearman Correlation Coeff.') + 
        theme_pubr(base_size = FONT_SIZE) +
        theme(plot.margin = margin(0,0,0,0, "cm")),
    plts[['aneuploidy_pancancer']] + 
        theme_pubr(base_size = FONT_SIZE) +
        theme(plot.margin = margin(0,0,0,0, "cm")),
    widths = c(1.15,0.13),
    common.legend = TRUE
) %>% annotate_figure(bottom = text_grob('Cancer Type', 
                                         size = FONT_SIZE, 
                                         family = FONT_FAMILY,
                                         vjust = -0.75)
                     ) +
    theme(plot.margin = margin(0.1,0.3,0.1,0.1, "cm"))

# prepare figure data
common_cols = intersect(colnames(df), colnames(df_pancan))
figdata = rbind(df[,common_cols], df_pancan[,common_cols]) %>% 
    rename(correlation = value) %>%
    mutate(method='Spearman')

# save
## plots
ggsave(plt, filename=output_file, units = 'cm', width=12, dpi=300, height=8, device=cairo_pdf)

## figure data
write_xlsx(
    x = list(correlation_aneuploidy = figdata),
    path = output_figdata
)

print('Done!')