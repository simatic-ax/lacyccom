USING AxUnit.Assert;

NAMESPACE Simatic.Ax.Library
    {TestFixture}
    CLASS DummyTestFixture
        {Test}
        METHOD PUBLIC DummyTest
            AxUnit.Assert.Equal(expected := TRUE, actual := TRUE);
        END_METHOD
    END_CLASS
END_NAMESPACE