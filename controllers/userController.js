let User;
let bcrypt;

try {
    User = require('../models/user');
    bcrypt = require('bcrypt');
} catch (err) {
    console.log('User model or bcrypt not available');
}

class UserController {
    static async createUser(req, res) {
        try {
            if (!User || !bcrypt) {
                return res.status(503).json({ error: 'User service not available' });
            }

            const { username, password } = req.body;
            
            // Hash the password
            const saltRounds = 10;
            const password_hash = await bcrypt.hash(password, saltRounds);
            
            const user = await User.create({
                username,
                password_hash
            });
            
            // Don't return the password hash
            const { password_hash: _, ...userResponse } = user.toJSON();
            res.status(201).json(userResponse);
        } catch (error) {
            if (error.name === 'SequelizeUniqueConstraintError') {
                res.status(400).json({ error: 'Username already exists' });
            } else {
                res.status(500).json({ error: error.message });
            }
        }
    }

    static async loginUser(req, res) {
        try {
            if (!User || !bcrypt) {
                return res.status(503).json({ error: 'User service not available' });
            }

            const { username, password } = req.body;
            
            const user = await User.findOne({ where: { username } });
            
            if (!user) {
                return res.status(401).json({ error: 'Invalid credentials' });
            }
            
            const isValidPassword = await bcrypt.compare(password, user.password_hash);
            
            if (!isValidPassword) {
                return res.status(401).json({ error: 'Invalid credentials' });
            }
            
            // Don't return the password hash
            const { password_hash: _, ...userResponse } = user.toJSON();
            res.json(userResponse);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    static async getUser(req, res) {
        try {
            if (!User) {
                return res.status(503).json({ error: 'User service not available' });
            }

            const { id } = req.params;
            const user = await User.findByPk(id);
            
            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }
            
            // Don't return the password hash
            const { password_hash: _, ...userResponse } = user.toJSON();
            res.json(userResponse);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    static async deleteUser(req, res) {
        try {
            if (!User) {
                return res.status(503).json({ error: 'User service not available' });
            }

            const { id } = req.params;
            const user = await User.findByPk(id);
            
            if (!user) {
                return res.status(404).json({ error: 'User not found' });
            }
            
            await user.destroy();
            res.json({ message: 'User deleted successfully' });
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
}

module.exports = UserController;