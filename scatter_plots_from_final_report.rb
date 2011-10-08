#! /usr/bin/env ruby1.9
#
#  scatter_plots_from_final_report.rb
#  Created by Stuart Glenn on 2007-12-20.
#
# Copyright (c) 2009, Oklahoma Medical Research Foundation
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the Oklahoma Medical Research Foundation nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL OKLAHOMA MEDICAL RESEARCH FOUNDATION BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# =Description
# A quickish script to take SNPs of data from a bead studio/express final report
# style final and produce scatter plots by gnuplot
#
# =File Format
# [Header]                                                                                
# BSGT Version    3.1.14                                                                  
# Processing Date 11/21/2007 13:14                                                                        
# Content         VC0010170-OPA.opa                                                               
# Num SNPs        19                                                                      
# Total SNPs      384                                                                     
# Num Samples     2550                                                                    
# Total Samples   2584                                                                    
# [Data]                                          original call (AB)              Original calls (bases)          
# Sample ID       SNP Name  Chr  Position  X Raw   Y Raw   X       Y Theta R  Allele1 - AB    Allele2 - AB    Allele1 - Top   Allele2 - Top   GC Score        extr_data


require 'getoptlong'
require 'tempfile'

class Snp
  include Enumerable
  attr_accessor :name, :chr, :pos
  def initialize(name, chr, pos)
    (@name, @chr, @pos) = name, chr, pos.to_i
  end
  
  def self.sort_chr(a,b)
    if a.to_i > 0 && b.to_i > 0 then
      a.to_i <=> b.to_i
    else
      a <=> b
    end
  end
  
  def ==(b)
    self.name == b.name
  end
  
  def <=>(b)
    self.chr == b.chr ? self.pos <=> b.pos : Snp.sort_chr(self.chr,b.chr)
  end
end

class ScatterPloterApp
  
  VERSION       = "2.0"
  REVISION_DATE = "2009-10-08"
  AUTHOR        = "Stuart Glenn <Stuart-Glenn@omrf.org>"
  COPYRIGHT     = "Copyright (c) 2009-11 Oklahoma Medical Research Foundation"
  
  CELLS = %w/d0 d1/
  TYPES = [:raw, :corrected, :r_theta]
  
  #
  # returns version information string
  # based on CVS tags
  #
  def version
      "Version: #{VERSION} Released: #{REVISION_DATE}\nWritten by #{AUTHOR}"
  end #version
    
    #
    # returns usage/help string
    #
    def usage
      <<-USAGE
      
Usage: #{File.basename $0}   
 -H|--help                Print this help message
 -v|--version             Print version information
 -f input_file            Specify the input report file containing SNP data
 
 This script will read out all the SNPs from the given final report file.
 From that it will create two scatter plots for each (a raw & a corrected).
 These file will be named SNP_NAME-raw.png and will be created in the
 current directory. It is advised at this point to first make a new folder
 and change into it before running this script.
 
USAGE
    end #usage
    
    #
    # process command line args
    #
    def get_options()
      opts = GetoptLong.new(
        [ "--help","-H",GetoptLong::NO_ARGUMENT ],
        [ "--version", "-v", GetoptLong::NO_ARGUMENT ],
        [ "-f",GetoptLong::REQUIRED_ARGUMENT],
        [ "-s",GetoptLong::REQUIRED_ARGUMENT]
      )
      
      opts.each do |opt, arg|
        case opt
          when "-f"
            @input_file = arg
          when "-s"
            @snp_file = arg
          when "--help"
            puts usage
            exit 0
          when "--version"
            puts "#{File.basename $0} - #{version}"
            puts ""
            puts "#{COPYRIGHT}. All Rights Reserved"
            puts "This software comes with ABSOLUTELY NO WARRANTY"
            exit 0
          else
            raise "Invalid option '#{opt}' with argument #{arg}."
        end #case
      end #each opt
      
    end #getOptions
    
    # 
    # Initializer, scan CLI args and setup stuff
    #
    def initialize
      get_options()
      unless @input_file then
        puts "Missing input file"
        puts usage()
        exit 1
      end
      @snps = find_snps()
    end

  #
  # starts running/doing the actual work
  #
  def run
    
    @snps.each do |s|
      snp_data_file = tmp_snp_data_file(s.name)
      TYPES.each do |type|
        make_plot(s.name,snp_data_file.path, type)
      end
      snp_data_file.unlink()
    end
    
    make_html_report()
  end #run
  
  :private

  def make_html_report
    @cell = 0
    @output_index = File.open("index.html","w")
    html_header()
    @snps.sort.each do |s|
      add_snp_to_html_report(s)
    end    
    html_footer()
    @output_index.close()    
  end
  
  def html_header
    @output_index.puts <<-EOF
    <HTML>
    <HEAD>
    <TITLE>#{File.basename(@input_file)} Plots</TITLE>
    <style type="text/css">
    tr.d0 td {
    	background-color: #E5E5E5; color: black;
    }
    tr.d1 td {
    	background-color: #F5F5F5; color: black;
    }
    </style>
    </HEAD>
    <BODY>
    <TABLE BORDER=1>
    <TR>
    <TH>SNP</TH>
    <TH>Chr</TH>
    <TH>Position</TH>
    <TH>Plot 1 (Raw)</TH>
    <TH>Plot 2 (Corrected)</TH>
    <TH>Plot 3 (Norm R vs Theta)</TH>
    </TR>
    EOF
  end
  
  def html_footer
    @output_index.puts <<-EOF
    </TABLE>
    </BODY>
    </HTML>
    EOF
  end
  
  def add_snp_to_html_report(snp)
    @output_index.puts <<-EOF
    <TR class=#{CELLS[@cell]}>
    <TD>#{snp.name}</TD>
    <TD>#{snp.chr}</TD>
    <TD>#{snp.pos}</TD>
    <TD><A HREF="#{snp.name}-raw.png">Raw</A></TD>
    <TD><A HREF="#{snp.name}-corrected.png">Corrected</A></TD>
    <TD><A HREF="#{snp.name}-r_theta.png">R Theta</A></TD>
    <TR>
    EOF
    @cell = 1 - @cell
  end
  
  #
  # Create a plot image, file will be named after snp_name
  #
  def make_plot(snp_name,data_file,plot_type)
    x_title = "x-#{plot_type}"
    y_title = "y-#{plot_type}"
    cols = "5:6"
    if :corrected == plot_type then
      cols = "7:8" 
    end
    #7 & 8 are theta & r
    if :r_theta == plot_type then
      cols = "9:10"
      y_title = 'Norm R'
      x_title = 'Theta'
    end
    plot_file = Tempfile.open("scatter-plot-#{$$}")
    plot_file.puts <<-EOF
set terminal png size 800,600 small enhanced xffffff x000000 x404040
set output "#{snp_name}-#{plot_type}.png"
set title "#{snp_name} #{plot_type}"
set xlabel "#{x_title}"
set ylabel "#{y_title}"
set key box
plot '< egrep "B\\W+B" #{data_file}' using #{cols} lt 3 title " BB", '< egrep "A\\W+B" #{data_file}' using #{cols} lt 4 title " AB", '< egrep "A\\W+A" #{data_file}' using #{cols} lt 1 title " AA", '< egrep "\\-\\W+\\-" #{data_file}' using #{cols} lt 9 title " --"       
    EOF
    plot_file.close
    system("gnuplot < #{plot_file.path}")
    plot_file.unlink
    puts "Plotted #{snp_name} as #{plot_type}"
  end #make_plot
  
  #
  # Create a temporary file containing only the data for the given snp
  # Does so currently using grep
  #
  def tmp_snp_data_file(snp)
   tmp_file = Tempfile.new("scatter-data-#{$$}")
   path = tmp_file.path
   source_path = @input_file.to_s.gsub(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF\n])/, '\\').gsub(/\n/, "'\n'").sub(/^$/, "''")
   system("grep -w #{snp} #{source_path} > #{path}")
   tmp_file
  end #tmp_snp_data_file
  
  #
  # Process the input file and get a list of all the snps therein
  #
  def find_snps()
    return snps_from_snp_file if @snp_file
    snps_in_file = []
    in_data = false
    in_header = true
    File.open(@input_file).each do |line|
      if in_header then
        if line =~ /^\[Data\].*$/i then
          in_header = false
        end
      elsif !in_header && !in_data then
        in_data = true
      elsif in_data && !in_header then
        (snp,chr,pos) = line.split(/\t/)[1,3]
        # snps_in_file[snp] = {:chr => chr.to_i, :pos => pos.to_i}
        snp = Snp.new(snp,chr,pos)
        snps_in_file.push(snp) unless snps_in_file.include?(snp)
      end #what section of the file
    end
    snps_in_file
  end #find_snps
  
  def snps_from_snp_file
    snps_in_file = []
    File.open(@snp_file).each do |line|
      snp = Snp.new(line.chomp,nil,nil)
      snps_in_file.push(snp)
    end
    return snps_in_file
  end
  
end #ScatterPloterAppApp


if $0 == __FILE__
    ScatterPloterApp.new.run
end
