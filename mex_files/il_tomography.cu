/*
 * This file is part of MULTEM.
 * Copyright 2016 Ivan Lobato <Ivanlh20@gmail.com>
 *
 * MULTEM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MULTEM is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MULTEM. If not, see <http:// www.gnu.org/licenses/>.
 */

#include <algorithm>

#include "math.cuh"
#include "types.cuh"
#include "matlab_types.cuh"
#include "traits.cuh"

#include "host_device_functions.cuh"
#include "input_multislice.cuh"
#include "output_multislice.hpp"
#include "atom_data.hpp"
#include "multislice.cuh"
#include "atomic_cross_section.cuh"

#include "input_tomography.cuh"
#include "output_tomography.hpp"
#include "tomography.cuh"

#include <mex.h>
#include "matlab_mex.cuh"

using mt::rmatrix_r;
using mt::rmatrix_c;
using mt::e_host;
using mt::e_device;

template<class TInput_Multislice>
void read_input_multislice(const mxArray *mx_input_multislice, TInput_Multislice &input_multislice)
{
	using value_type_r = mt::Value_type<TInput_Multislice>;

	input_multislice.precision = mt::eP_float;
	input_multislice.device = mt::e_device; 
	input_multislice.cpu_ncores = 1; 
	input_multislice.cpu_nthread = 4; 
	input_multislice.gpu_device = 0;
	input_multislice.gpu_nstream = 1;
	input_multislice.set_device();

	input_multislice.simulation_type = mt::eTEMST_STEM;
	input_multislice.phonon_model = mt::ePM_Still_Atom;
	input_multislice.interaction_model = mt::eESIM_Multislice;
	input_multislice.potential_slicing = mt::ePS_dz_Sub;
	input_multislice.potential_type = mt::ePT_Lobato_0_12;

	input_multislice.E_0 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "E_0");
	int Z = mx_get_scalar_field<int>(mx_input_multislice, "Z");
	double rms3d = mx_get_scalar_field<double>(mx_input_multislice, "rms3d");
	double fwsig = mx_get_scalar_field<double>(mx_input_multislice, "fwhm")*mt::c_fwhm2sigma;

	bool bwl = false;
	bool pbc_xy = true;

	int nx = 1024;
	int ny = 1024;
	double lx = 20;
	double ly = 20;
	double dz = 0.4; 				

	/******************************** set atom *********************************/
	int natoms = 1;
	double atoms[6];
	atoms[0] = Z; 
	atoms[1] = 0.5*lx; 
	atoms[2] = 0.5*ly; 
	atoms[3] = 0.0; 
	atoms[4] = sqrt(rms3d*rms3d+fwsig*fwsig); 
	atoms[5] = 1.0;
	input_multislice.atoms.set_Atoms(natoms, atoms, lx, ly);
	input_multislice.grid.set_input_data(nx, ny, lx, ly, dz, bwl, pbc_xy);

	/****************************** Objective lens ********************************/
	input_multislice.obj_lens.m = mx_get_scalar_field<int>(mx_input_multislice, "obj_lens_m"); 												// momentum of the vortex
	input_multislice.obj_lens.f = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_f"); 									// defocus(Angstrom)
	input_multislice.obj_lens.Cs3 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_Cs3")*mt::c_mm_2_Ags; 				// third order spherical aberration(mm-->Angstrom)
	input_multislice.obj_lens.Cs5 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_Cs5")*mt::c_mm_2_Ags; 				// fifth order aberration(mm-->Angstrom)
	input_multislice.obj_lens.mfa2 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_mfa2"); 								// magnitude 2-fold astigmatism(Angstrom)
	input_multislice.obj_lens.afa2 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_afa2")*mt::c_deg_2_rad; 			// angle 2-fold astigmatism(degrees-->rad)
	input_multislice.obj_lens.mfa3 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_mfa3"); 								// magnitude 3-fold astigmatism(Angstrom)
	input_multislice.obj_lens.afa3 = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_afa3")*mt::c_deg_2_rad; 			// angle 3-fold astigmatism(degrees-->rad)
	input_multislice.obj_lens.inner_aper_ang = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_inner_aper_ang")*mt::c_mrad_2_rad; 		// inner aperture(mrad-->rad)
	input_multislice.obj_lens.outer_aper_ang = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_outer_aper_ang")*mt::c_mrad_2_rad; 		// outer aperture(mrad-->rad)
	input_multislice.obj_lens.sf = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_sf"); 									// defocus spread(Angstrom)
	input_multislice.obj_lens.nsf = mx_get_scalar_field<int>(mx_input_multislice, "obj_lens_nsf"); 											// Number of integration steps for the defocus Spread
	input_multislice.obj_lens.beta = mx_get_scalar_field<value_type_r>(mx_input_multislice, "obj_lens_beta")*mt::c_mrad_2_rad; 			// divergence semi-angle(mrad-->rad)
	input_multislice.obj_lens.nbeta = mx_get_scalar_field<int>(mx_input_multislice, "obj_lens_nbeta"); 										// Number of integration steps for the divergence semi-angle
	input_multislice.obj_lens.zero_defocus_type = mt::eZDT_Last;
	input_multislice.obj_lens.zero_defocus_plane = 0.0;	
	input_multislice.lens.set_input_data(input_multislice.E_0, input_multislice.grid);

	/********************************* Detectors ********************************/
	value_type_r lambda = mt::get_lambda(input_multislice.E_0);
	mxArray *mx_detector = mxGetField(mx_input_multislice, 0, "detector");
	input_multislice.detector.type = mt::eDT_Circular;
	mx_detector = mxGetField(mx_detector, 0, "cir");
	input_multislice.detector.resize(1);
	auto inner_ang = mx_get_scalar_field<value_type_r>(mx_detector, 0, "inner_ang")*mt::c_mrad_2_rad;
	input_multislice.detector.g_inner[0] = sin(inner_ang)/lambda;
	auto outer_ang = mx_get_scalar_field<value_type_r>(mx_detector, 0, "outer_ang")*mt::c_mrad_2_rad;
	input_multislice.detector.g_outer[0] = sin(outer_ang)/lambda;

	/********************************* Scanning ********************************/
	mt::Atom_Cal<double> atom_cal;
	mt::Atomic_Data atomic_data;
	atomic_data.Load_Data(input_multislice.potential_type);
	mt::Atom_Type<double, mt::e_host> atom_type;

	atomic_data.To_atom_type_CPU(Z, mt::c_Vrl, mt::c_nR, 0.0, atom_type);
	atom_cal.Set_Atom_Type(input_multislice.potential_type, &atom_type);
	auto rmax = atom_cal.AtomicRadius_Cutoff(3, 0.005);

	input_multislice.scanning.type = mt::eST_Line;
	input_multislice.scanning.grid_type = mt::eGT_Regular;
	input_multislice.scanning.ns = mt::c_nR;
	input_multislice.scanning.x0 = 0.5*lx;
	input_multislice.scanning.y0 = 0.5*ly;
	input_multislice.scanning.xe = 0.5*lx;
	input_multislice.scanning.ye = 0.5*ly+rmax;
	input_multislice.scanning.set_grid();

	input_multislice.validate_parameters();
 }

template<class TInput_Tomography>
void read_tomography(const mxArray *mx_input_tomography, TInput_Tomography &input_tomography, bool full =true)
{
	using value_type_r = mt::Value_type<TInput_Tomography>;

	input_tomography.precision = mx_get_scalar_field<mt::ePrecision>(mx_input_tomography, "precision");
	input_tomography.device = mx_get_scalar_field<mt::eDevice>(mx_input_tomography, "device"); 
	input_tomography.cpu_nthread = mx_get_scalar_field<int>(mx_input_tomography, "cpu_nthread"); 
	input_tomography.gpu_device = mx_get_scalar_field<int>(mx_input_tomography, "gpu_device"); 
	input_tomography.gpu_nstream = mx_get_scalar_field<int>(mx_input_tomography, "gpu_nstream"); 
	input_tomography.set_device();

	input_tomography.tm_u0 = mx_get_r3d_field<value_type_r>(mx_input_tomography, "tm_u0");
	input_tomography.tm_p0 = mx_get_r3d_field<value_type_r>(mx_input_tomography, "tm_p0");
	/***************************get cross section*****************************/
	input_tomography.Z = mx_get_scalar_field<int>(mx_input_tomography, "Z");

	if(full)
	{
		mt::Input_Multislice<float, e_device> input_multislice;
		read_input_multislice(mx_input_tomography, input_multislice);

		mt::Atomic_Cross_Section<float, e_device> atomic_cross_section;
		atomic_cross_section.set_input_data(&input_multislice);

		atomic_cross_section.get(input_tomography.r, input_tomography.fr);
	}

	/*************************************************************************/
	auto angle = mx_get_matrix_field<rmatrix_r>(mx_input_tomography, 0, "angle");
	mt::Vector<value_type_r, e_host> angle_host;
	mt::assign(angle, angle_host);
	mt::scale(angle_host, mt::c_deg_2_rad);
	mt::assign(angle_host, input_tomography.angle);

	mxArray *mx_data = mxGetField(mx_input_tomography, 0, "data");	
	if(full)
	{
		int nimage = mxGetN(mx_data)*mxGetM(mx_data);
		input_tomography.image.resize(nimage);
		for(auto i = 0; i<input_tomography.image.size(); i++)
		{
			auto image = mx_get_matrix_field<rmatrix_r>(mx_data, i, "image");
			mt::assign(image, input_tomography.image[i]);
		}
	}

	value_type_r dR = mx_get_scalar_field<value_type_r>(mx_input_tomography, "dR");
	auto image = mx_get_matrix_field<rmatrix_r>(mx_data, 0, "image");
	bool bwl = false;
	bool pbc_xy = false;

	int nx = image.cols;
	int ny = image.rows;
	value_type_r lx = nx*dR;
	value_type_r ly = ny*dR;
	value_type_r dz = 0.5; 

	input_tomography.input_atoms = mx_get_scalar_field<mt::eInput_Atoms>(mx_input_tomography, "input_atoms");

	auto atoms = mx_get_matrix_field<rmatrix_r>(mx_input_tomography, "atoms");
	if((input_tomography.is_input_atoms())&&(atoms.rows>0))
	{
		auto atoms_min = mx_get_matrix_field<rmatrix_r>(mx_input_tomography, "atoms_min");
		auto atoms_max = mx_get_matrix_field<rmatrix_r>(mx_input_tomography, "atoms_max");
		input_tomography.atoms.set_Atoms(atoms.rows, atoms.real, atoms_min.real, atoms_max.real);
	}
	else
	{	
		auto natoms = mx_get_scalar_field<int>(mx_input_tomography, "natoms"); 
		input_tomography.atoms.resize(natoms);
	}
	input_tomography.grid.set_input_data(nx, ny, lx, ly, dz, bwl, pbc_xy);

	input_tomography.r0_min = mx_get_scalar_field<value_type_r>(mx_input_tomography, "r0_min"); 
	input_tomography.rTemp = mx_get_scalar_field<value_type_r>(mx_input_tomography, "rTemp"); 

	input_tomography.validate_parameters();
 }

void set_output_tomography(const mxArray *mx_input_tomography, mxArray *&mx_output_tomography, mt::Output_Tomography_Matlab &output_tomography)
{
	mt::Input_Tomography<double> input_tomography;
	read_tomography(mx_input_tomography, input_tomography, false);
	output_tomography.set_input_data(&input_tomography);

	const char *field_names_output_tomography[] = {"temp", "chi2", "atoms"};
	int number_of_fields_output_tomography = 3;
	mwSize dims_output_tomography[2] = {1, 1};

	mx_output_tomography = mxCreateStructArray(2, dims_output_tomography, number_of_fields_output_tomography, field_names_output_tomography);

	// output_tomography.temp = mx_create_matrix_field<rmatrix_r>(mx_output_tomography, "temp", output_tomography.temp.m_size, 1);
	// output_tomography.chi2 = mx_create_matrix_field<rmatrix_r>(mx_output_tomography, "chi2", output_tomography.chi2.m_size, 1);

	auto atoms = mx_create_matrix_field<rmatrix_r>(mx_output_tomography, "atoms", input_tomography.atoms.size(), 4);

	output_tomography.Z.rows = atoms.rows;
	output_tomography.Z.cols = 1;
	output_tomography.Z.m_size = output_tomography.Z.rows*output_tomography.Z.cols;
	output_tomography.Z.real = atoms.real + 0*atoms.rows;

	output_tomography.x.rows = atoms.rows;
	output_tomography.x.cols = 1;
	output_tomography.x.m_size = output_tomography.x.rows*output_tomography.x.cols;
	output_tomography.x.real = atoms.real + 1*atoms.rows;

	output_tomography.y.rows = atoms.rows;
	output_tomography.y.cols = 1;
	output_tomography.y.m_size = output_tomography.y.rows*output_tomography.y.cols;
	output_tomography.y.real = atoms.real + 2*atoms.rows;

	output_tomography.z.rows = atoms.rows;
	output_tomography.z.cols = 1;
	output_tomography.z.m_size = output_tomography.z.rows*output_tomography.z.cols;
	output_tomography.z.real = atoms.real + 3*atoms.rows;
}

template<class T, mt::eDevice dev>
void il_tomography(const mxArray *mxB, mt::Output_Tomography_Matlab &output_tomography)
{
	mt::Input_Tomography<T> input_tomography;
	read_tomography(mxB, input_tomography);

	mt::Tomography<T, dev> tomography;
	tomography.set_input_data(&input_tomography);

	tomography.run(output_tomography);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	mt::Output_Tomography_Matlab output_tomography;
	set_output_tomography(prhs[0], plhs[0], output_tomography);

	if(output_tomography.is_float_host())
	{
		il_tomography<float, mt::e_host>(prhs[0], output_tomography);
	}
	else if(output_tomography.is_double_host())
	{
		il_tomography<double, mt::e_host>(prhs[0], output_tomography);
	}
	if(output_tomography.is_float_device())
	{
		il_tomography<float, mt::e_device>(prhs[0], output_tomography);
	}
	else if(output_tomography.is_double_device())
	{
		il_tomography<double, mt::e_device>(prhs[0], output_tomography);
	}
}