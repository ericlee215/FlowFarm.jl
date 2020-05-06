abstract type AbstractLocalTurbulenceIntensityModel end

struct LocalTIModelNoLocalTI{} <: AbstractLocalTurbulenceIntensityModel

end

struct LocalTIModelMaxTI{TF} <: AbstractLocalTurbulenceIntensityModel
    astar::TF
    bstar::TF
end

struct LocalTIModelGaussTI{TF} <: AbstractLocalTurbulenceIntensityModel
    ti::TF
end

function calculate_local_ti(ambient_ti, ti_model::LocalTIModelNoLocalTI)
    return ambient_ti
end

# compute wake spread parameter based on local turbulence intensity
function _k_star_func(ti_ust)
    
    # calculate wake spread parameter from Niayifar and Porte Agel (2015, 2016)
    k_star_ust = 0.3837*ti_ust+0.003678
    
end

function calculate_local_ti(ambient_ti, windfarm, windfarmstate, ti_model::LocalTIModelMaxTI; turbine_id=1, tol=1E-6)

    # calculate local turbulence intensity at turbI
    
    # initialize the TI_area_ratio to 0.0 for each turbine
    TI_area_ratio = 0.0

    # initialize local ti tmp for downstream turbine
    ti_dst_tmp = windfarmstate.turbine_local_ti[turbine_id]

    # extract the number of turbines
    nturbines = length(ti_dst_tmp)
    
    # loop over upstream turbines
    for u=1:nturbines
    
        # get index of upstream turbine
        turb = windfarmstate.sorted_turbine_index[u]
        
        # skip turbine's influence on itself
        if turb == turbine_id; continue; end
        
        # calculate downstream distance between wind turbines
        x = windfarmstate.turbine_x[turbine_id] - windfarmstate.turbine_x[turb]
        
        if x > tol

            # extract state and design info for current upstream turbine
            d_ust = windfarm.turbine_definitions[def_id].rotor_diameter
            yaw_ust = windfarmstate.turbine_yaw[turb]
            ti_ust = windfarmstate.turbine_local_ti[turb]

            # calculate ct at the current upstream turbine
            def_id = windfarm.turbine_definition_ids[turb]
            ct_model = windfarm.turbine_definitions[def_id].ct_model
            ct_ust = calculate_ct(windfarmstate.turbine_inflow_velcities[turb], ct_model)

            # determine the far-wake onset location
            astar = ti_model.astar
            bstar = ti_model.bstar
            x0 = _gauss_yaw_potential_core(d_ust, yaw_ust, ct_ust, astar, ti_ust, bstar)
        
            # calculate the distance from the onset of far-wake
            deltax0 = x - x0

            # calculate wake spread rate for current upstream turbine
            kstar_ust = _k_star_func(ti_ust)
        
            # calculate horizontal and vertical spread standard deviations
            sigmay = sigmaz = _gauss_yaw_spread(x, x0, kstar_ust, d_ust, yaw_ust)

            # determine the initial wake angle at the onset of far wake
            theta_c_0 = _bpa_theta_0(yaw_ust, ct_ust)
    
            # horizontal cross-wind wake displacement from hub
            call wake_offset_func(x, rotorDiameter(turb), theta_c_0, x0, yaw(turb), &
                                    & ky_local(turb), kz_local(turb), &
                                    Ct_local(turb), sigmay, sigmaz, wake_offset)
    
            ! cross wind distance from point location to upstream turbine wake center
            deltay = turbineYw(turbI) - (turbineYw(turb) + wake_offset)   
        
            ! save ti_area_ratio and ti_dst to new memory locations to avoid 
            ! aliasing during differentiation
            TI_area_ratio_tmp = TI_area_ratio
            TI_dst_tmp = TIturbs(turbI)
            TI_ust_tmp = TIturbs(turb)
    
            ! update local turbulence intensity
            call added_ti_func(TI, Ct_local(turb), x, ky_local(turb), rotorDiameter(turb), & 
                                & rotorDiameter(turbI), deltay, turbineZ(turb), &
                                & turbineZ(turbI), sm_smoothing, TI_ust_tmp, &
                                & TI_calculation_method, TI_area_ratio_tmp, &
                                & TI_dst_tmp, TI_area_ratio, TIturbs(turbI))
        end if
    
    end do
    
    ! calculate wake spreading parameter at turbI based on local turbulence intensity
    if (calc_k_star .eqv. .true.) then

        call k_star_func(TIturbs(turbI), k_star)
        ky_local(turbI) = k_star
        kz_local(turbI) = k_star

    end if
        
end