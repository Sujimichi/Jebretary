require 'factory_girl'
def rand_no
  (rand*100000).round
end


def persistent_file_without_craft
  s = <<EOF
GAME
{
	version = 0.21.1
	Title = test (Sandbox)
	Description = No description available.
	Mode = 0
	Status = 1
	scene = 5
	flag = Katateochi/Flags/my_flag
	PARAMETERS
	{
		FLIGHT
		{
			CanQuickSave = True
			CanQuickLoad = True
			CanAutoSave = True
			CanUseMap = True
			CanSwitchVesselsNear = True
			CanSwitchVesselsFar = True
			CanTimeWarpHigh = True
			CanTimeWarpLow = True
			CanEVA = True
			CanIVA = True
			CanBoard = True
			CanRestart = True
			CanLeaveToEditor = True
			CanLeaveToTrackingStation = True
			CanLeaveToSpaceCenter = True
			CanLeaveToMainMenu = False
		}
		EDITOR
		{
			CanSave = True
			CanLoad = True
			CanStartNew = True
			CanLaunch = True
			CanLeaveToSpaceCenter = True
			CanLeaveToMainMenu = False
			startUpMode = 0
			craftFileToLoad = 
		}
		TRACKINGSTATION
		{
			CanFlyVessel = True
			CanAbortVessel = True
			CanLeaveToSpaceCenter = True
			CanLeaveToMainMenu = False
		}
		SPACECENTER
		{
			CanGoInVAB = True
			CanGoInSPH = True
			CanGoInTrackingStation = True
			CanLaunchAtPad = True
			CanLaunchAtRunway = True
			CanLeaveToMainMenu = True
		}
		DIFFICULTY
		{
			MissingCrewsRespawn = True
		}
	}
	SCENARIO
	{
		name = ProgressTracking
		scene = 5, 7, 8
		Progress
		{
			FirstLaunch
			{
				completed = 64.0200000000044
			}
			AltitudeRecord
			{
				completed = 1705839.91281925
				record = 83559286.4796305
			}
			FirstCrewToSurvive
			{
				completed = 2762.43096435484
				crew
				{
					crews = 0, 1, 2
				}
			}
			ReachedSpace
			{
				completed = 350.96812011716
				vessel
				{
					name = Untitled Space Craft
					flag = Squad/Flags/default
				}
				crew
				{
					crews = 0, 1, 2
				}
			}
			Spacewalk
			{
				completed = 32532.9376135359
				crew
				{
					crews = 0
				}
			}
			KSCLanding
			{
				completed = 4824837.02132866
			}
			RunwayLanding
			{
				completed = 154327.192579964
			}
			Sun
			{
				reached = 1705839.91281925
				Orbit
				{
					completed = 1705839.91281925
					vessel
					{
						name = Probe1 Debris
						flag = Squad/Flags/default
					}
				}
			}
			Kerbin
			{
				reached = 433.742060546829
				Orbit
				{
					completed = 433.742060546829
					vessel
					{
						name = Untitled Space Craft
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 0, 1, 2
					}
				}
				Escape
				{
					completed = 26554.6189953619
				}
				Landing
				{
					completed = 2699.9909643549
					vessel
					{
						name = Untitled Space Craft
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 0, 1, 2
					}
				}
				Splashdown
				{
					completed = 172530.974164888
				}
				Rendezvous
				{
					completed = 377096.01799335
				}
				Docking
				{
					completed = 379764.169741854
				}
				SurfaceEVA
				{
					completed = 262934.588153119
					crew
					{
						crews = 1
					}
				}
				ReturnFromOrbit
				{
					completed = 2699.9909643549
					vessel
					{
						name = Untitled Space Craft
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 0, 1, 2
					}
				}
				ReturnFromSurface
				{
					completed = 154327.192579964
					vessel
					{
						name = ScreamingGnat
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 3
					}
				}
			}
			Mun
			{
				reached = 26554.6189953619
				Flyby
				{
					completed = 26554.6189953619
				}
				Orbit
				{
					completed = 32457.4776135342
					vessel
					{
						name = ApolloStock
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 0, 1, 2
					}
				}
				Escape
				{
					completed = 116798.822715193
				}
				Landing
				{
					completed = 101380.433231298
					vessel
					{
						name = ApolloStock Lander
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 0, 2
					}
				}
				Rendezvous
				{
					completed = 4890149.8012864
				}
				Docking
				{
					completed = 4890249.57559605
				}
				SurfaceEVA
				{
					completed = 101554.113231333
					crew
					{
						crews = 0
					}
				}
				ReturnFromFlyBy
				{
					completed = 153658.722724303
					vessel
					{
						name = ApolloStock
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 2, 1, 0
					}
				}
				ReturnFromOrbit
				{
					completed = 153658.722724303
					vessel
					{
						name = ApolloStock
						flag = Squad/Flags/default
					}
					crew
					{
						crews = 2, 1, 0
					}
				}
			}
			Minmus
			{
				reached = 827364.965516574
				Flyby
				{
					completed = 827364.965516574
				}
				Orbit
				{
					completed = 2981944.10939952
					vessel
					{
						name = FirstContact
						flag = Squad/Flags/default
					}
				}
				Escape
				{
					completed = 864900.837093723
				}
			}
		}
	}
	FLIGHTSTATE
	{
		version = 0.21.1
		UT = 4933405.07790554
		activeVessel = 30
	}
	ROSTER
	{
		CREW
		{
			name = Jebediah Kerman
			brave = 0.5
			dumb = 0.5
			badS = True
			state = 1
			ToD = 257951.825257043
			idx = 0
		}
		CREW
		{
			name = Bill Kerman
			brave = 0.5
			dumb = 0.8
			badS = False
			state = 1
			ToD = 0
			idx = 1
		}
		CREW
		{
			name = Bob Kerman
			brave = 0.3
			dumb = 0.1
			badS = False
			state = 0
			ToD = 0
			idx = 0
		}
		CREW
		{
			name = Milmore Kerman
			brave = 0.7031192
			dumb = 0.3137673
			badS = True
			state = 0
			ToD = 163082.988677565
			idx = 1
		}
		CREW
		{
			name = Edlas Kerman
			brave = 0.8582411
			dumb = 0.1734093
			badS = False
			state = 0
			ToD = 193639.933203125
			idx = -1
		}
		CREW
		{
			name = Hallan Kerman
			brave = 0.8328099
			dumb = 0.1922576
			badS = True
			state = 0
			ToD = 254487.203405762
			idx = -1
		}
		CREW
		{
			name = Jonmon Kerman
			brave = 0.94678
			dumb = 0.9438838
			badS = False
			state = 0
			ToD = 189625.251748047
			idx = -1
		}
		CREW
		{
			name = Wilrey Kerman
			brave = 0.1965522
			dumb = 0.183267
			badS = False
			state = 0
			ToD = 250289.444158936
			idx = -1
		}
		CREW
		{
			name = Obdan Kerman
			brave = 0.5588631
			dumb = 0.806024
			badS = False
			state = 0
			ToD = 5054650.76545615
			idx = -1
		}
		CREW
		{
			name = Donbrett Kerman
			brave = 0.3170292
			dumb = 0.1241957
			badS = False
			state = 0
			ToD = 4932174.31434531
			idx = -1
		}
		CREW
		{
			name = Lolong Kerman
			brave = 0.4101316
			dumb = 0.04475009
			badS = True
			state = 0
			ToD = 4975984.78683371
			idx = -1
		}
		CREW
		{
			name = Fredfry Kerman
			brave = 0.7175853
			dumb = 0.9654412
			badS = False
			state = 0
			ToD = 4955808.57375998
			idx = -1
		}
		CREW
		{
			name = Jenny Kerman
			brave = 0.3981652
			dumb = 0.1753308
			badS = False
			state = 0
			ToD = 5029709.48661703
			idx = -1
		}
		CREW
		{
			name = Lemsen Kerman
			brave = 0.6495876
			dumb = 0.9070311
			badS = False
			state = 0
			ToD = 4993186.23527426
			idx = -1
		}
		CREW
		{
			name = Gus Kerman
			brave = 0.9598402
			dumb = 0.8801316
			badS = False
			state = 0
			ToD = 4925083.90983481
			idx = -1
		}
		CREW
		{
			name = Samdas Kerman
			brave = 0.1535705
			dumb = 0.6270008
			badS = False
			state = 1
			ToD = 5034081.90788168
			idx = 0
		}
		CREW
		{
			name = Tomly Kerman
			brave = 0.4276463
			dumb = 0.08341897
			badS = True
			state = 0
			ToD = 5070919.17594809
			idx = -1
		}
		CREW
		{
			name = Kirdos Kerman
			brave = 0.02608347
			dumb = 0.8572469
			badS = False
			state = 1
			ToD = 4976375.206603
			idx = 1
		}
		CREW
		{
			name = Hans Kerman
			brave = 0.1526467
			dumb = 0.4595407
			badS = False
			state = 0
			ToD = 4999145.5492391
			idx = -1
		}
		CREW
		{
			name = Luke Kerman
			brave = 0.9225935
			dumb = 0.2389203
			badS = False
			state = 0
			ToD = 5011348.2836141
			idx = -1
		}
		CREW
		{
			name = Sigler Kerman
			brave = 0.9427183
			dumb = 0.941449
			badS = False
			state = 0
			ToD = 4947064.39041037
			idx = -1
		}
		CREW
		{
			name = Barger Kerman
			brave = 0.996033
			dumb = 0.4091656
			badS = False
			state = 0
			ToD = 5005783.61228842
			idx = -1
		}
		CREW
		{
			name = Bobbald Kerman
			brave = 0.89704
			dumb = 0.4298036
			badS = False
			state = 0
			ToD = 5029257.9485311
			idx = -1
		}
		CREW
		{
			name = Randall Kerman
			brave = 0.1690881
			dumb = 0.3495315
			badS = False
			state = 0
			ToD = 5049558.14918417
			idx = -1
		}
		CREW
		{
			name = Sonfen Kerman
			brave = 0.9722505
			dumb = 0.3913477
			badS = False
			state = 0
			ToD = 4983376.94884923
			idx = -1
		}
		CREW
		{
			name = Munwig Kerman
			brave = 0.9031731
			dumb = 0.3832003
			badS = True
			state = 0
			ToD = 5060885.10326806
			idx = -1
		}
		CREW
		{
			name = Lemkin Kerman
			brave = 0.1021888
			dumb = 0.9175761
			badS = True
			state = 0
			ToD = 4964582.67337517
			idx = -1
		}
		APPLICANTS
		{
			RECRUIT
			{
				name = Raymin Kerman
				brave = 0.4360616
				dumb = 0.4213238
				badS = True
				state = 0
				ToD = 5028591.22947592
				idx = -1
			}
			RECRUIT
			{
				name = Philfal Kerman
				brave = 0.2597385
				dumb = 0.2921969
				badS = False
				state = 0
				ToD = 4950973.5319509
				idx = -1
			}
			RECRUIT
			{
				name = Milley Kerman
				brave = 0.6612542
				dumb = 0.9547153
				badS = False
				state = 0
				ToD = 4958069.72488303
				idx = -1
			}
			RECRUIT
			{
				name = Edlu Kerman
				brave = 0.2270683
				dumb = 0.8851448
				badS = False
				state = 0
				ToD = 4996481.80412192
				idx = -1
			}
			RECRUIT
			{
				name = Newbrett Kerman
				brave = 0.008681417
				dumb = 0.4767223
				badS = False
				state = 0
				ToD = 4934521.26182455
				idx = -1
			}
			RECRUIT
			{
				name = Sigbin Kerman
				brave = 0.217247
				dumb = 0.4283957
				badS = True
				state = 0
				ToD = 4910500.19782919
				idx = -1
			}
			RECRUIT
			{
				name = Kerbo Kerman
				brave = 0.7382534
				dumb = 0.6308829
				badS = False
				state = 0
				ToD = 4967933.89491793
				idx = -1
			}
			RECRUIT
			{
				name = Kirble Kerman
				brave = 0.02989304
				dumb = 0.6795853
				badS = False
				state = 0
				ToD = 4980341.91869274
				idx = -1
			}
			RECRUIT
			{
				name = Thomlin Kerman
				brave = 0.5081879
				dumb = 0.7011421
				badS = False
				state = 0
				ToD = 5000458.80773242
				idx = -1
			}
			RECRUIT
			{
				name = Macberry Kerman
				brave = 0.953576
				dumb = 0.05849862
				badS = False
				state = 0
				ToD = 5082825.13388107
				idx = -1
			}
			RECRUIT
			{
				name = Loeny Kerman
				brave = 0.8863393
				dumb = 0.1506047
				badS = False
				state = 0
				ToD = 4986949.7305905
				idx = -1
			}
		}
	}
}


EOF
  


end
