https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/src_main/engine/host.cpp#L2549
See this code;

for the scroll part, when fps is lower than the tickrate:

when host_remainder is bigger than >= tick interval, it means that there is less frames available to compute than the tickrate
when this happens, it runs more ticks to compute more CUserCmd with the same inputs, to account for missing frames when calling CreateMove/_Host_RunFrame_Input.
in fact during scroll, your old buttons are taken instead of new ones that are computed, so it makes scroll more consistant, because the game isn't updating your buttons more faster than a tickrate, so you can scroll very fast and the game wouldn't reg that your button states have changed,

so it results in better scrolls.


now, for the 100 fps part:

what happens when it is exactly 100 (if tickrate is 100), it calls exactly once per frame, so per tick, _Host_RunFrame_Input with a prevremainder of an interval per tick (which is consistant so it makes the mouse feels a bit laggy, but also very more consistant since you have a delay of a tick interval between to your movements. 
since prevremainder is exactly an interval per tick, CreateMove's frametime for computing mouse movements is actually 0, so the mouse movement are not done there.
for the actual calculation it is done below,
they're done when going in CL_ExtraMouseSample, and the g_ClientGlobalVariables.frametime is a tick interval.

this is called very consistantly, at the same very delay of an interval per tick each frames, so it results in a more accurate mouse movement, due to the fact that the angles are updated consistantly even if it feels laggy.
this is mainly due because the frametime gets always the same value, and that CreateMove doesn't need to account for lower/bigger framerate.
so the accumulated mouse x/y are the same every frames which results in a very accurate move.

now,
when fps is higher, prevremainder is in fact below a tick interval and since host remainder is very low, due to the higher framerate, the frametime's of CreateMove will be close to a tick interval, but not exactly (interval per tick - prevremainder), so mouse x/y accumulated movements are applied to the viewangles in a different manner now.

the rest will be handled by CL_ExtraMouseSample which has a lower value also for frametime, so it results in a better reactivity, but with a lot less consistency.


Imo, the proper way that Valve have should done it is using interpolation, but that would unfortunately delay the player's input by a tick interval in order to make the interpolation between angles and old angles.
So I understand completely their point on this.

now don't get me wrong, the mouse calculations are done to be consistant, but not in the way you think, in fact it does only gives you better reactions to your movements irl when it can when you have higher fps, so the turns are move reactive, but it does still affect your gameplay.
