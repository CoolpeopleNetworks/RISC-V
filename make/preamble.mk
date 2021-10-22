# Save ${d} and replace it with the current directory.
sp 				:= $(sp).x
dirstack_$(sp)	:= $(d)
d				:= $(dir)
