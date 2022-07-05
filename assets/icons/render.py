#!/usr/bin/env python3

import os
import subprocess

files = [file for file in os.listdir() if file.endswith('.svg')]
for file in files :
	fn = file[:-4]
	size = int(fn.split('_')[-1])
	outname = '_'.join(fn.split('_')[:-1]) + '.png'
	print(outname)
	subprocess.run(['inkscape', '--export-filename={0}'.format(os.path.join('png', outname)), '-w', str(size), '-h', str(size), file], stderr=open(os.devnull, 'w'))
	subprocess.run(['inkscape', '--export-filename={0}'.format(os.path.join('png', '2.0x', outname)), '-w', str(size*2), '-h', str(size*2), file], stderr=open(os.devnull, 'w'))
	subprocess.run(['inkscape', '--export-filename={0}'.format(os.path.join('png', '3.0x', outname)), '-w', str(size*3), '-h', str(size*3), file], stderr=open(os.devnull, 'w'))
