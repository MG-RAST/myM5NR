# MAKEFILE FOR DOWNLOADING and postprocessing

downloads = rdp.download greengenes.download


rdp.download : rdp.download
			curl -z rdp.download -L -s -S -o rdp_current_Bacteria_unaligned.gb.gz 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz'
			curl -z rdp.download -L -s -S-o rdp_current_Archaea_unaligned.gb.gz 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz'
			curl -z rdp.download -L -s -S-o rdp_current_Fungi_unaligned.gb.gz 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' 
			curl -z rdp.download -L -s -S-o RDP-VERSION.txt 'http://rdp.cme.msu.edu/download/releaseREADME.txt'
			touch rdp.download


greengenes: greengenes.download
			curl -z greengenes.download -L -s -S -o greengenes_current_GREENGENES_gg16S_unaligned.fasta.gz 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz'
			touch greengenes.download

	
