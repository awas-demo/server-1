const express = require('express');
const UserController = require('../controllers/userController');

const router = express.Router();

router.post('/', UserController.createUser);
router.post('/login', UserController.loginUser);
router.get('/:id', UserController.getUser);
router.delete('/:id', UserController.deleteUser);

module.exports = router;