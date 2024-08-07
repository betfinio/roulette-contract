// Code generated by mockery v2.43.2. DO NOT EDIT.

package mocks

import (
	context "context"

	bridges "github.com/smartcontractkit/chainlink/v2/core/bridges"

	mock "github.com/stretchr/testify/mock"
)

// ExternalInitiatorManager is an autogenerated mock type for the ExternalInitiatorManager type
type ExternalInitiatorManager struct {
	mock.Mock
}

// DeleteJob provides a mock function with given fields: ctx, webhookSpecID
func (_m *ExternalInitiatorManager) DeleteJob(ctx context.Context, webhookSpecID int32) error {
	ret := _m.Called(ctx, webhookSpecID)

	if len(ret) == 0 {
		panic("no return value specified for DeleteJob")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(context.Context, int32) error); ok {
		r0 = rf(ctx, webhookSpecID)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// FindExternalInitiatorByName provides a mock function with given fields: ctx, name
func (_m *ExternalInitiatorManager) FindExternalInitiatorByName(ctx context.Context, name string) (bridges.ExternalInitiator, error) {
	ret := _m.Called(ctx, name)

	if len(ret) == 0 {
		panic("no return value specified for FindExternalInitiatorByName")
	}

	var r0 bridges.ExternalInitiator
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, string) (bridges.ExternalInitiator, error)); ok {
		return rf(ctx, name)
	}
	if rf, ok := ret.Get(0).(func(context.Context, string) bridges.ExternalInitiator); ok {
		r0 = rf(ctx, name)
	} else {
		r0 = ret.Get(0).(bridges.ExternalInitiator)
	}

	if rf, ok := ret.Get(1).(func(context.Context, string) error); ok {
		r1 = rf(ctx, name)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Notify provides a mock function with given fields: ctx, webhookSpecID
func (_m *ExternalInitiatorManager) Notify(ctx context.Context, webhookSpecID int32) error {
	ret := _m.Called(ctx, webhookSpecID)

	if len(ret) == 0 {
		panic("no return value specified for Notify")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(context.Context, int32) error); ok {
		r0 = rf(ctx, webhookSpecID)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// NewExternalInitiatorManager creates a new instance of ExternalInitiatorManager. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewExternalInitiatorManager(t interface {
	mock.TestingT
	Cleanup(func())
}) *ExternalInitiatorManager {
	mock := &ExternalInitiatorManager{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}