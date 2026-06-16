using InstrumentationInterface;
using Microsoft.AspNetCore.Mvc;
using PharmaGo.UsersService.IBusinessLogic;
using PharmaGo.UsersService.Models.In;
using PharmaGo.UsersService.Models.Out;

namespace PharmaGo.UsersService.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UsersController : ControllerBase
    {
        private readonly IUsersManager _userManager;
        private readonly IStructuredLogger _structuredLogger;

        public UsersController(IUsersManager manager, IStructuredLogger structuredLogger)
        {
            _userManager = manager;
            _structuredLogger = structuredLogger;
        }

        private string CorrelationId =>
            HttpContext.Request.Headers["X-Correlation-ID"].FirstOrDefault()?.Trim()
            ?? HttpContext.TraceIdentifier;

        [HttpPost]
        public IActionResult CreateUser([FromBody] UserModelRequest userModel)
        {
            try
            {
                var user = _userManager.CreateUser(userModel.UserName, userModel.UserCode,
                                                   userModel.Email, userModel.Password,
                                                   userModel.Address, userModel.RegistrationDate);
                _structuredLogger.LogInformation(
                    "User created",
                    new Dictionary<string, object>
                    {
                        ["component"] = "UsersController",
                        ["operation"] = "create_user",
                        ["outcome"] = "success",
                        ["user_name"] = user.UserName ?? "",
                        ["correlation_id"] = CorrelationId
                    });
                var userModelResponse = new UserModelResponse(user);
                return Ok(userModelResponse);
            }
            catch (Exception ex)
            {
                _structuredLogger.LogError(
                    "User creation failed",
                    ex,
                    new Dictionary<string, object>
                    {
                        ["component"] = "UsersController",
                        ["operation"] = "create_user",
                        ["outcome"] = "failed",
                        ["user_name"] = userModel?.UserName ?? "unknown",
                        ["correlation_id"] = CorrelationId
                    });
                throw;
            }
        }
    }
}
