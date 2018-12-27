global total_iter_num progress_bar;
total_iter_num = 0;
if exist('progress_bar', 'var') && ~isempty(progress_bar) ...
		&& isvalid(progress_bar)	
	waitbar(0, progress_bar, ...
		sprintf('Simulation Progress: %d/%d', total_iter_num, TOTAL_NUM));
else
	progress_bar = waitbar(total_iter_num/TOTAL_NUM, ...
		sprintf('Simulation Progress: %d/%d', total_iter_num, TOTAL_NUM));
	jframe=getJFrame(progress_bar);
	jframe.setAlwaysOnTop(1);
end
