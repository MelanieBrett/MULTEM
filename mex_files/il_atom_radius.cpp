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

#include "types.cuh"
#include "atomic_data.hpp"

#include <mex.h>
#include "matlab_mex.cuh"

using mt::rmatrix_r;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{
	auto potential_type = mx_get_scalar<mt::ePotential_Type>(prhs[0]);
	auto Dim = mx_get_scalar<int>(prhs[1]);
	auto Vrl = mx_get_scalar<double>(prhs[2]);

	auto r = mx_create_matrix<rmatrix_r>(mt::c_nAtomsTypes, 3, plhs[0]);

	mt::Atom_Cal<double> atom_cal;
	mt::Atomic_Data atomic_data;
	atomic_data.Load_Data(potential_type);
	mt::Atom_Type<double, mt::e_host> atom_type;

	int charge = 0;
	for(auto i = 0; i<r.rows; i++)
	{
		atomic_data.To_atom_type_CPU(i+1, mt::c_Vrl, mt::c_nR, 0.0, atom_type);
		atom_cal.Set_Atom_Type(potential_type, charge, &atom_type);
		r.real[i+0*r.rows] = atom_cal.AtomicRadius_rms(Dim);
		r.real[i+1*r.rows] = atom_cal.AtomicRadius_Cutoff(Dim, Vrl);
		r.real[i+2*r.rows] = atom_type.ra_e;
	}
}