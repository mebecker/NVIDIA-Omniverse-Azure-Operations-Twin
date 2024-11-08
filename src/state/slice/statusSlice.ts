/*
 * SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: MIT
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface StatusState {
    assetId: string;
    assetStatus: 'nominal' | 'warning' | 'fault';
}

const initialState: StatusState = {
    assetId: '',
    assetStatus: 'nominal',
};

const statusSlice = createSlice({
    name: 'status',
    initialState,
    reducers: {
        setStatus: (state, action: PayloadAction<{ assetId: string, assetStatus: 'nominal' | 'warning' | 'fault'}>) => {
            state.assetId = action.payload.assetId;
            state.assetStatus = action.payload.assetStatus;
        },
    },
});

export const { setStatus } = statusSlice.actions;
export default statusSlice.reducer;
